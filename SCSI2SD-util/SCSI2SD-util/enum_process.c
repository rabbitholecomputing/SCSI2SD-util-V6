#include <windows.h>
#include <stdio.h>
#include <tchar.h>
#include <psapi.h>

// To ensure correct resolution of symbols, add Psapi.lib to TARGETLIBS
// and compile with -DPSAPI_VERSION=1

char* PrintProcessNameAndID( DWORD processID )
{
    TCHAR szProcessName[MAX_PATH] = TEXT("<unknown>");
    char *output;
    // size_t length = 0;

    // Get a handle to the process.
    HANDLE hProcess = OpenProcess( PROCESS_QUERY_INFORMATION |
                                   PROCESS_VM_READ,
                                   FALSE, processID );

    // Get the process name.

    if (NULL != hProcess )
    {
        HMODULE hMod;
        DWORD cbNeeded;

        if ( EnumProcessModules( hProcess, &hMod, sizeof(hMod), 
             &cbNeeded) )
        {
            GetModuleBaseName( hProcess, hMod, szProcessName, 
                               sizeof(szProcessName)/sizeof(TCHAR) );
        }
    }

    // Print the process name and identifier.
    // _tprintf( TEXT("%s  (PID: %lu)\n"), szProcessName, processID );

    // Release the handle to the process.
    CloseHandle( hProcess );

    // wcstombs_s(&length, output, MAX_PATH, szProcessName, MAX_PATH);
    output = szProcessName;

    return output;
}

int find_process( char *name )
{
    // Get the list of process identifiers.

    DWORD aProcesses[1024], cbNeeded, cProcesses;
    unsigned int i;
    unsigned int c = 0;

    if ( !EnumProcesses( aProcesses, sizeof(aProcesses), &cbNeeded ) )
    {
        return 1;
    }


    // Calculate how many process identifiers were returned.

    cProcesses = cbNeeded / sizeof(DWORD);

    // Print the name and process identifier for each process.

    for ( i = 0; i < cProcesses; i++ )
    {
        if( aProcesses[i] != 0 )
        {
	  char *theName = PrintProcessNameAndID( aProcesses[i] );
	  char *ss = NULL;
	  ss = strstr(theName, name);
	  if (ss != NULL)
	    {
	      c++;
	    }
        }
    }

    if (c > 1)
      {
	return 1;
      }

    return 0;
}
