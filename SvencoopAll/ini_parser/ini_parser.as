/**
 * [UTILITY] INI Parser
 *
 * An Angelscript library to read, parse, store, and backup INI file.
 * Mainly created for parsing AMXX plugin configs.
 * 
 * Pros :
 * 1. Support section-less properties,
 * 2. Support comment lines,
 * 3. Support whitespaces to both property key and value,
 * 4. Support both map (tested) and plugin (untested) scripts,
 * 5. Support file appending/updating/merging to destinated store file,
 * 6. File backup,
 * 7. Use AngelScript's dictionary addon to store INI data,
 * 8. Since its stored in dictionary objects, multiple file reading is not needed.
 *
 *
 * Consts :
 * 1. Multiple property values is not supported (last value is used instead).
 *
 *
 * Note :
 * For a default backup folder path, makes sure folder "backup" is created.
 * For map script,		svencoop\scripts\maps\store\backup\
 * For plugin script,	svencoop\scripts\plugins\store\backup\
 *
 *
 * Based on MeRcyLeZZ's Settings API (load/save data to INI files)
 * https://forums.alliedmods.net/showthread.php?t=243202
 * 
 * And Wikipedia's INI file webpage as information to understand INI format
 * https://en.wikipedia.org/wiki/INI_file
 *
 * By Anggara_nothing
 */

namespace INI
{
	/**
	 * Enable/Disable Debug Mode.
	 */
	const bool   DEBUG_MODE     = false;

	/**
	 * Temporary folder name.
	 * Currently unused.
	 */
	const string TEMP_FOLDER	= "temp/";

	/**
	 * Backup folder name.
	 */
	const string BACKUP_FOLDER	= "backup/";

	/**
	 * Persistent write access folder.
	 * For map script.
	 */
	const string STORE_MAP_FOLDER		= "scripts/maps/store/";

	/**
	 * Persistent write access folder.
	 * For plugin script.
	 */
	const string STORE_PLUGIN_FOLDER	= "scripts/plugins/store/";

	/**
	 * Indicates this INI parser input is from File@ handle.
	 */
	const string USE_FILE_OBJECT	= "LOADED FROM FILE OBJECT";

	/**
	 * Section name for section-less properties.
	 * This section won't create its section header on output and inserted at top position.
	 */
	const string GLOBAL_SECTION		= "000_INI_PARSER_GLOBAL_SECTION_000";

	enum StoreMode
	{
		/**
		 * Append/Merge current parsed INI to the destination.
		 */
		STORE_APPEND = 0,

		/**
		 * Write/Overwrite current parsed INI to the destination.
		 */
		STORE_OVERWRITE
	}

	/**
	 * Indicates ReadProperty succeed parsing a valid line.
	 */
	const int PROPERTY_RETURN_VALID		= 1;

	/**
	 * Indicates ReadProperty parsing a section header suffix ( [ ).
	 */
	const int PROPERTY_RETURN_END		= 0;

	/**
	 * Indicates ReadProperty parsing a blank line.
	 */
	const int PROPERTY_RETURN_BLANK		= -1;

	/**
	 * Indicates ReadProperty parsing a comment line.
	 */
	const int PROPERTY_RETURN_COMMENT	= -2;

	/**
	 * Log message to the Angelscript log.
	 * Only if debug mode is enabled.
	 */
	void log_printF( const string &in szMessage )
	{
		if( DEBUG_MODE )
			g_Log.PrintF( szMessage );
	}

	class Parser : Persistable
	{
		/**
		 * Key   = Section Name.
		 * Value = Section's property dictionaries.
		 */
		private dictionary@ m_dictSec = 
		{
			// reserved global section
			{ GLOBAL_SECTION, dictionary={} }
		};

		/**
		 * Gets all sections.
		 *
		 * @return		Sections dictionary.
		 */
		dictionary@ get() const
		{
			return m_dictSec;
		}

		/**
		 * Gets a section.
		 *
		 * @param szSectionName		Section name.
		 * @return		Section dictionary. Return null if not exists.
		 */
		dictionary@ get( const string &in szSectionName ) const
		{
			return cast<dictionary@>( m_dictSec[szSectionName] );
		}

		/**
		 * Gets a property value of a section.
		 *
		 * @param szSectionName		Section name.
		 * @param szPropertyKey		Property key.
		 * @return		Property value. Return empty string if not exists.
		 */
		string get( const string &in szSectionName, const string &in szPropertyKey ) const
		{
			dictionary@ section = get( szSectionName );

			// Return empty string
			if( section is null ) return string();

			return string( section[szPropertyKey] );
		}

		protected void setClassname()
		{
			_classname = "INI";
		}

		/**
		 * Default constructor.
		 */
		Parser()
		{
			setClassname();

			@_file = null;
		}

		/**
		 * Constructor.
		 *
		 * @param szFilepath		File input path.
		 */
		Parser( const string& in szFilepath )
		{
			setClassname();

			load( szFilepath );
		}

		/**
		 * Constructor.
		 *
		 * @param file		File@ handle to input.
		 */
		Parser( File@ file )
		{
			setClassname();

			load( @file );
		}

		/**
		 * Parses the input file.
		 *
		 * @return		True if succeed, false otherwise.
		 */
		bool parse() override
		{
			if( !isReady() )
			{
				log_printF( "["+_classname+" Parse] File is not ready, abort!\n" );
				return false;
			}

			string buffer;
			dictionary@ lastSection = null;

			while( !_file.EOFReached() )
			{
				// Read one line at a time
				_file.ReadLine( buffer );

				if( ReadSection( buffer, buffer ) )
				{
					if( !m_dictSec.exists( buffer ) )
					{
						// Create new section
						@lastSection = dictionary={};
						m_dictSec.set( buffer, @lastSection );
					}
					else
					{
						// Get stored section
						m_dictSec.get( buffer, @lastSection );
					}
				}
				// Failed to read section?
				// Read property instead
				else
				{
					string key, value;
					int returnCode = ReadProperty( buffer, key, value );

					if( returnCode == PROPERTY_RETURN_BLANK || returnCode == PROPERTY_RETURN_COMMENT )
						continue;
					else
					if( returnCode == 0 )
						break;
					else
					{
						// this property is not belongs to any section?
						if( lastSection is null )
						{
							// get global section
							dictionary@ pSectiontion = cast<dictionary@>( m_dictSec[GLOBAL_SECTION] );
							if( pSectiontion !is null )
							{
								pSectiontion.set( key,value );
							}
						}
						else
						{
							lastSection.set( key,value );
						}
					}
				}
			}

			close();
			return true;
		}

		/**
		 * Stores the parsed INI to the destination.
		 * Default configuration is set (Backup file and data sorting).
		 *
		 * @param uiStoreMode		Store mode.
		 * @return		True if succeed, false otherwise.
		 */
		bool store( StoreMode uiStoreMode ) override
		{
			return store( uiStoreMode, true, true );
		}

		/**
		 * Stores the parsed INI to the destination.
		 *
		 * @param uiStoreMode	Store mode.
		 * @param makeBackup	True if backup feature is enabled, false otherwise.
		 * @param doSort		True if sorting feature is enabled, false otherwise.
		 * @return		True if succeed, false otherwise.
		 */
		bool store( StoreMode uiStoreMode, const bool makeBackup, const bool doSort = true )
		{
			log_printF( "["+_classname+" Store] Destination= " +_fileOutputPath+ "\n" );

			// overwrite?
			if( isOverwritable() && !makeBackup )
			{
				log_printF( "["+_classname+" Store] WARNING: File will be overwritten without a backup!\n" );
			}

			// Create backup
			if( makeBackup )
			{
				// backup failure, abort!
				if( isFileExists( _fileOutputPath ) && !createBackup( _fileOutputPath ) )
				{
					log_printF( "["+_classname+" Store] Backup failure, abort!\n" );
					return false;
				}
			}

			// Now, set to correct mode
			if( _fileOutputPath != USE_FILE_OBJECT )
				@_file = g_FileSystem.OpenFile( _fileOutputPath, getStoreFileFlags( uiStoreMode ) );

			// file handle failure...
			if( !isReady() )
			{
				log_printF( "["+_classname+" Store] File is not ready, abort!\n" );
				return false;
			}

			// Clear old INI data
			// then insert parsed one
			if( uiStoreMode == STORE_OVERWRITE )
			{
				log_printF( "["+_classname+" Store] STORE_OVERWRITE\n" );

				array<string> seckeys = m_dictSec.getKeys();

				// Do quicksorting
				if( doSort )
				{
					//seckeys.sortAsc();
					Sorting::quickSort( seckeys, 0, int(seckeys.length())-1 );
				}

				dictionary@ pSection = null;
				string key;

				for( uint i = 0; i < seckeys.length(); i++ )
				{
					key = seckeys[i];

					// dont write section header for global section
					if( !key.IsEmpty() && key != GLOBAL_SECTION )
						_file.Write( "[" +key+ "]\n" );

					m_dictSec.get( key, @pSection );
					if( pSection !is null )
					{
						array<string> optkeys = pSection.getKeys();

						// Do quicksorting
						if( doSort )
						{
							//optkeys.sortAsc();
							Sorting::quickSort( optkeys, 0, int(optkeys.length())-1 );
						}

						for( uint k = 0; k < optkeys.length(); k++ )
						{
							key = optkeys[k];

							string optvalue;
							pSection.get( key, optvalue );

							_file.Write( key +" = "+ optvalue +"\n" );
						}
					}

					_file.Write( "\n" );
				}
			}
			// Store current file to FileStream
			// Update old properties
			// and append new sections with their properties
			else
			if( uiStoreMode == STORE_APPEND )
			{
				log_printF( "["+_classname+" Store] STORE_APPEND\n" );

				// get filesize before closing
				size_t filesize = _file.GetSize();

				// close current file
				close();

				// Empty file?
				// Move to overwrite mode instead
				if( filesize <= 0 )
				{
					log_printF( "["+_classname+" Store] Destination file is empty, moved to STORE_OVERWRITE\n" );
					// Backup already created in this point
					return store( STORE_OVERWRITE, false, doSort );
				}

				FileStream@ streamHandle = FileStream( _fileOutputPath );
				// file read failure, abort!
				if( !streamHandle.parse() )
				{
					log_printF( "["+_classname+" Store] File parsing failed, abort!\n" );
					return false;
				}

				// Prepare the output file
				if( _fileOutputPath != USE_FILE_OBJECT )
					@_file = g_FileSystem.OpenFile( _fileOutputPath, OpenFile::WRITE );

				// file handle failure...
				if( !isReady() )
				{
					log_printF( "["+_classname+" Store] File is not ready, abort!\n" );
					return false;
				}

				// cache our INI data
				dictionary cachedDic = m_dictSec;
				array<string> cdKeys = cachedDic.getKeys();
				for( uint id = 0; id < cdKeys.length(); id++ )
				{
					string key = cdKeys[id];

					cachedDic[key] = dictionary( m_dictSec[key] );
				}

				dictionary@ lastSection = null;
				string buffer, sectionName;
				string propKey, propValue, newValue;
				int returnCode;
				uint lastPos;

				// Update existing sections
				for( lastPos = 0; lastPos < streamHandle.szBuffers.length(); lastPos++ )
				{
					// Read one line at a time
					buffer = streamHandle.szBuffers[lastPos];

					// Update/Insert global section first
					if( cachedDic.exists( GLOBAL_SECTION ) )
					{
						cachedDic.get( GLOBAL_SECTION, @lastSection );

						// No more left data?
						if( lastSection !is null && lastSection.getSize() <= 0 )
						{
							// Force remove global section from cached dictionary
							cachedDic.delete( sectionName );
							@lastSection = null;

							// Step back
							--lastPos;

							continue;
						}

						// Set section name
						sectionName = GLOBAL_SECTION;

						// Parse this line
						returnCode = ReadProperty( buffer, propKey, propValue );

						// We got parseable line here!
						if( returnCode >= PROPERTY_RETURN_VALID )
						{
							// property exists
							if( lastSection.get(propKey, newValue) )
							{
								// new value
								if( newValue != propValue )
								{
									newValue = propKey +" = "+ newValue +"\n";
									streamHandle.szBuffers[lastPos] = newValue;
								}
							}

							// Clear cache
							// delete this property from cached dict
							lastSection.delete( propKey );
						}
						// Comment line?
						else if( returnCode == PROPERTY_RETURN_COMMENT )
						{
							continue;
						}
						// Global section is still exists?
						else
						if( lastSection !is null )
						{
							// Section ended?
							if( returnCode == PROPERTY_RETURN_END )
							{
								// Set pos one step back
								--lastPos;
							}

							// Insert all left data
							array<string> gsKeys = lastSection.getKeys();
							for( uint s = 0; s < gsKeys.length(); s++ )
							{
								string key  = gsKeys[s];
								string prop = key +" = "+ string( lastSection[key] ) +"\n";
								streamHandle.szBuffers.insertAt( lastPos, prop );
							}

							// Force remove global section from cached dictionary
							cachedDic.delete( sectionName );
							@lastSection = null;
						}

						// Check global again...
						continue;
					}

					// is this section?
					string temp;
					if( ReadSection( buffer, temp ) )
					{
						// Retrieve this section
						sectionName = temp;
						cachedDic.get( sectionName, @lastSection );

						// Next!
						continue;
					}

					// No more left data?
					if( lastSection !is null && lastSection.getSize() <= 0 )
					{
						// Force remove section from cached dictionary
						cachedDic.delete( sectionName );
						@lastSection = null;

						// Step back
						--lastPos;

						continue;
					}

					// Read a section property
					returnCode = ReadProperty( buffer, propKey, propValue );
					// We got parseable line here!
					if( returnCode >= PROPERTY_RETURN_VALID )
					{
						// this property is not belongs to any section?
						if( lastSection is null )
						{
							// Next!
							continue;
						}

						// Update property value
						// property exists
						if( lastSection.get( propKey, newValue ) )
						{
							// new value
							if( newValue != propValue )
							{
								newValue = propKey +" = "+ newValue +"\n";
								streamHandle.szBuffers[lastPos] = newValue;
							}
						}

						// Clear cache
						// delete this property from cached dict
						lastSection.delete( propKey );
					}
					// Comment line?
					else if( returnCode == PROPERTY_RETURN_COMMENT )
					{
						continue;
					}
					// This section is still exists?
					else
					if( lastSection !is null )
					{
						// Section ended?
						if( returnCode == PROPERTY_RETURN_END )
						{
							// Set pos one step back
							--lastPos;
						}

						// Insert all left data
						array<string> secKeys = lastSection.getKeys();
						for( uint s = 0; s < secKeys.length(); s++ )
						{
							string key  = secKeys[s];
							string prop = key +" = "+ string( lastSection[key] ) +"\n";
							streamHandle.szBuffers.insertAt( lastPos, prop );
						}

						// Force remove section from cached dictionary
						cachedDic.delete( sectionName );
						@lastSection = null;
					}
				}

				// Insert new sections
				if( cachedDic.getSize() > 0 )
				{
					@lastSection = null;

					// Insert our metadata
					string metadata;
					DateTime currentTime = DateTime();
					snprintf( metadata, "; Imported from %1\n; %2-%3-%4 %5:%6:%7\n", _fileInputPath, currentTime.GetDayOfMonth(), currentTime.GetMonth(), currentTime.GetYear(), currentTime.GetHour(), currentTime.GetMinutes(), currentTime.GetSeconds() );
					streamHandle.szBuffers.insertLast( metadata );

					array<string> secKeys = cachedDic.getKeys();
					// Do quicksorting
					if( doSort )
					{
						Sorting::quickSort( secKeys, 0, int(secKeys.length())-1 );
					}

					for( uint s = 0; s < secKeys.length(); s++ )
					{
						// Get section name
						sectionName = secKeys[s];

						// Retrieve section
						cachedDic.get( sectionName, @lastSection );

						// This section is not empty?
						if( lastSection !is null )
						{
							// Format the section header
							sectionName = "[" +sectionName+ "]\n";

							// Insert a new section
							streamHandle.szBuffers.insertLast( sectionName );

							// Insert corresponding properties
							array<string> optKeys = lastSection.getKeys();
							// Do quicksorting
							if( doSort )
							{
								Sorting::quickSort( optKeys, 0, int(optKeys.length())-1 );
							}

							for( uint o = 0; o < optKeys.length(); o++ )
							{
								// Get property key
								propKey = optKeys[o];

								// Retrieve property value
								if( lastSection.get( propKey, propValue ) )
								{
									// Insert a property
									streamHandle.szBuffers.insertLast( propKey +" = "+ propValue +"\n" );
								}
							}

							// Newline
							streamHandle.szBuffers.insertLast( "\n" );
						}
					}
				}

				// And finally, write to output file !!!!
				for( uint i = 0; i < streamHandle.szBuffers.length(); i++ )
				{
					_file.Write( streamHandle.szBuffers[i] );
				}
			}

			close();
			log_printF( "["+_classname+" Store] File stored!\n" );
			return true;
		}

		/**
		 * Parses a line for a section name.
		 *
		 * @param input		Input string/line.
		 * @param linedata	Output string to buffer.
		 * @return		True if succeed, false otherwise.
		 */
		bool ReadSection( const string &in input, string &out linedata )
		{
			// Seek to setting's section
			linedata = input;

			// Replace newlines with a null character
			linedata = linedata.Replace( "\n", "" );

			// New section starting
			if (linedata[0] == '[')
			{
				// Store section name without braces
				linedata = linedata.Replace( "[", "" );
				linedata = linedata.Replace( "]", "" );

				return true;
			}

			return false;
		}

		/**
		 * Parses a line for a property.
		 *
		 * @param input		Input string/line.
		 * @param linedata	Output string to buffer.
		 * @return		True if succeed, false otherwise.
		 */
		int ReadProperty( const string &in input, string &out key, string &out value )
		{
			// Seek to setting's key
			string linedata = input;

			// Replace newlines with a null character
			linedata = linedata.Replace( "\n", "" );

			// Blank line
			if ( linedata.Length() == 0 || linedata.IsEmpty() )
				return PROPERTY_RETURN_BLANK;

			// Comment line
			if ( linedata[0] == ';' )
				return PROPERTY_RETURN_COMMENT;

			// Section ended?
			if (linedata[0] == '[')
				return PROPERTY_RETURN_END;

			linedata.Trim();
			uint firstEqual = linedata.FindFirstOf( '=' );

			// Get key
			key = linedata.SubString( 0, firstEqual );
			key.Trim();

			// Get value
			value = linedata.SubString( firstEqual+1, linedata.Length() );
			value.Trim();

			return PROPERTY_RETURN_VALID;
		}
	}

	class FileStream : Persistable
	{
		private array<string> szBuffers(0);

		/**
		 * Gets buffered file.
		 */
		array<string> @szBuffers
		{
			get { return szBuffers; }
		}

		protected void setClassname()
		{
			_classname = "FileStream";
		}

		/**
		 * Default constructor.
		 */
		FileStream()
		{
			setClassname();
		}

		/**
		 * Constructor.
		 *
		 * @param szFilepath		File input path.
		 */
		FileStream( const string& in szFilename )
		{
			setClassname();

			load( szFilename );
		}

		/**
		 * Constructor.
		 *
		 * @param file		File@ handle to input.
		 */
		FileStream( File@ file )
		{
			setClassname();

			load( @file );
		}

		/**
		 * Parses the input file.
		 *
		 * @return		True if succeed, false otherwise.
		 */
		bool parse() override
		{
			if( !isReady() )
			{
				log_printF( "["+_classname+" Parse] File is not ready, abort!\n" );
				return false;
			}

			// Empty file?
			if( _file.GetSize() <= 0 )
			{
				close();

				log_printF( "["+_classname+" Parse] File is empty!\n" );

				return true;
			}

			string buffer;
			while( !_file.EOFReached() )
			{
				// Read one line at a time
				_file.ReadLine( buffer );

				// Write to cached buffer
				szBuffers.insertLast( buffer + "\n" );
			}

			close();

			return true;
		}

		/**
		 * Stores the parsed file to the destination.
		 *
		 * @param uiStoreMode		Store mode.
		 * @return		True if succeed, false otherwise.
		 */
		bool store( StoreMode uiStoreMode ) override
		{
			// not allowed?
			if( isOverwritable() && uiStoreMode != STORE_OVERWRITE )
			{
				log_printF( "["+_classname+" Store] Overwrite is not allowed, abort!\n" );
				return false;
			}

			// Now, set to correct mode
			if( _fileOutputPath != USE_FILE_OBJECT )
				@_file = g_FileSystem.OpenFile( _fileOutputPath, getStoreFileFlags( uiStoreMode ) );

			// file handle failure...
			if( !isReady() )
			{
				log_printF( "["+_classname+" Store] File is not ready, abort!\n" );
				return false;
			}

			uint bufLen = szBuffers.length();
			for( uint i = 0; i < bufLen; i++ )
			{
				// Write to output at same line
				_file.Write( szBuffers[i] );
			}

			close();

			return true;
		}
	}

	abstract class Persistable
	{
		protected string _classname = "Persistable";
		protected File@  _file = null;
		protected string _fileInputPath;
		protected string _fileOutputPath;

		/**
		 * Gets file handle.
		 *
		 * @return		File handle.
		 */
		File@ getFile() const
		{
			return _file;
		}

		/**
		 * Sets file handle.
		 *
		 * @param value		File handle.
		 */
		void setFile(File@ value)
		{
			@_file = @value;
		}

		/**
		 * Checks whether file handle is ready to proceed.
		 *
		 * @return		True if file is valid and open, false otherwise.
		 */
		bool isReady()
		{
			return ( _file !is null && _file.IsOpen() );
		}

		/**
		 * Checks whether file input is overwritable.
		 *
		 * @return		True if file is exists and not empty, false otherwise.
		 */
		bool isOverwritable()
		{
			File@ fileToOverwrite = @_file;

			// Open mode first, to check file is exists
			if( _fileOutputPath != USE_FILE_OBJECT )
				@fileToOverwrite = g_FileSystem.OpenFile( _fileOutputPath, OpenFile::READ );

			// file not found...
			if( fileToOverwrite is null || !fileToOverwrite.IsOpen() )
				return false;

			// Get filesize
			size_t fileSize = fileToOverwrite.GetSize();

			// Close now
			fileToOverwrite.Close();

			// this is not an empty file
			if( fileSize > 0 )
				return true;

			return false;
		}

		/**
		 * Checks whether file is exists.
		 *
		 * @param filePath		File path.
		 * @return		True if file is exists, false otherwise.
		 */
		bool isFileExists( const string &in filePath )
		{
			File@ fileToCheck = @_file;

			// Open mode first, to check file is exists
			if( _fileOutputPath != USE_FILE_OBJECT )
				@fileToCheck = g_FileSystem.OpenFile( filePath, OpenFile::READ );

			// file not found...
			if( fileToCheck is null || !fileToCheck.IsOpen() )
				return false;

			return true;
		}

		/**
		 * Loads file.
		 *
		 * @param szFilename		File path.
		 * @return		True if succeed, false otherwise.
		 */
		bool load( const string& in szFilename )
		{
			_fileInputPath  = szFilename;
			_fileOutputPath = szFilename;

			@_file = g_FileSystem.OpenFile( szFilename, OpenFile::READ );

			return ( _file !is null && _file.IsOpen() );
		}

		/**
		 * Loads file.
		 *
		 * @param file		File handle.
		 * @return		True if succeed, false otherwise.
		 */
		bool load( File@ file )
		{
			_fileOutputPath = USE_FILE_OBJECT;

			@_file = @file;

			return ( _file !is null && _file.IsOpen() );
		}

		/**
		 * Close current file handle.
		 */
		void close()
		{
			if( _file !is null )
			_file.Close();
		}

		/**
		 * Parses the input file.
		 *
		 * @return		True if succeed, false otherwise.
		 */
		bool parse()
		{
			return false;
		}

		/**
		 * Stores the parsed file to the destination.
		 *
		 * @param uiStoreMode		Store mode.
		 * @return		True if succeed, false otherwise.
		 */
		bool store( StoreMode uiStoreMode )
		{
			return false;
		}

		/**
		 * Stores the parsed file to the destination.
		 *
		 * @param szFilename		File destination path.
		 * @param uiStoreMode		Store mode.
		 * @return		True if succeed, false otherwise.
		 */
		bool store( const string &in szFilename, StoreMode uiStoreMode )
		{
			_fileOutputPath = szFilename;

			return store( uiStoreMode );
		}

		/**
		 * Gets open file flags for specific store mode.
		 *
		 * @return		OpenFile enum.
		 */
		OpenFileFlags_t getStoreFileFlags( const StoreMode uiStoreMode ) const
		{
			switch( uiStoreMode )
			{
				case STORE_OVERWRITE :
					return OpenFile::WRITE;

				case STORE_APPEND :
					return OpenFile::APPEND;

				default :
					break;
			}

			return OpenFile::READ;
		}
	}

	/**
	 * Gets a correct persistent store path.
	 *
	 * @return		Path to store a file.
	 */
	string getStorePath()
	{
		return ( g_Module.GetModuleName() == "MapModule" ? STORE_MAP_FOLDER : STORE_PLUGIN_FOLDER );
	}

	/**
	 * Creates a backup copy to the destination.
	 *
	 * @param filePath		File path to backup.
	 * @param backupPath	Backup destination folder path.
	 * @return		True if succeed, false otherwise.
	 */
	bool createBackup( string &in filePath, const string &in backupPath = getStorePath() + BACKUP_FOLDER )
	{
		log_printF( "[FileBackup] Started! " +filePath+ "\n" );

		// File is not exists
		/*if( !isFileExists( filePath ) )
		{
			log_printF( "[FileBackup] File is not exists!\n" );
			return false;
		}*/

		FileStream@ streamHandle = FileStream( filePath );

		// file read failure, abort!
		if( !streamHandle.parse() )
		{
			log_printF( "[FileBackup] File parsing failed, abort!\n" );
			return false;
		}

		bool isWindows = false;
		DateTime currentTime = DateTime();

		// Linux
		uint lastSlash = filePath.FindLastOf( "/" );
		isWindows = ( lastSlash == String::INVALID_INDEX );

		// Windows?
		if( isWindows )
		{
			lastSlash = filePath.FindLastOf( "\\" );
		}

		// Get filename
		string filename = filePath;
		if( lastSlash != String::INVALID_INDEX )
		{
			filename = filename.SubString( lastSlash+1 );
		}

		// Construct correct path
		snprintf( filename, "%1_%2_%3_%4_%5_%6_%7", currentTime.GetDayOfMonth(), currentTime.GetMonth(), currentTime.GetYear(), currentTime.GetHour(), currentTime.GetMinutes(), currentTime.GetSeconds(), filename );
		string newPath = backupPath + filename;

		// Invert slashes for Windows
		if( isWindows )
		{
			newPath = newPath.Replace( "/", "\\" );
		}

		bool result = streamHandle.store( newPath, STORE_OVERWRITE );

		log_printF( "[FileBackup] File " +(result?"succeed":"failed")+ " to created! " +newPath+ "\n" );

		return result;
	}

}

namespace Sorting
{
	// https://en.wikipedia.org/wiki/Quicksort
	// https://stackoverflow.com/a/36703987
	void quickSort( array<string> &inout strings, int start, int end )
	{
		int i = start;
		int j = end;
		string pivot = strings[ start + (end - start) / 2 ];

		while ( i <= j )
		{
			while ( strings[i].ICompare(pivot) < 0 )
			{
				i++;
			}

			while ( strings[j].ICompare(pivot) > 0 )
			{
				j--;
			}

			if (i <= j)
			{
				swap( strings, i, j );
				i++;
				j--;
			}
		}

		//call quickSort recursively
		if ( start < j )
		{
			quickSort( strings, start, j );
		}
		if ( i < end )
		{
			quickSort( strings, i, end );
		}
	}

	void swap( array<string> &inout strings, int i, int j )
	{
		string temp = strings[i];
		strings[i] = strings[j];
		strings[j] = temp;
	}
}
