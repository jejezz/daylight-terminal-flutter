#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <Windows.h>

#include "flutter_pty.h"

#include "include/dart_api.h"
#include "include/dart_api_dl.h"
#include "include/dart_native_api.h"

/* Daylight Terminal patch (vs upstream 0.4.2; see packages/flutter_pty/PATCHES.md):
 *  - Convert command line, environment and working directory from UTF-8 to UTF-16 properly
 *    (non-ASCII paths such as Korean ones used to be mangled).
 *  - Do not put the executable on the command line twice (arguments[0] already is the executable).
 *  - Quote executables and arguments that contain spaces or quotes using the Windows rules.
 */

/* Returns a newly allocated UTF-16 copy of a UTF-8 string. The caller frees it. */
static LPWSTR utf8_to_wide(const char *s)
{
    if (s == NULL)
    {
        return NULL;
    }

    int length = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);

    if (length <= 0)
    {
        return NULL;
    }

    LPWSTR wide = malloc((size_t)length * sizeof(WCHAR));

    if (wide == NULL)
    {
        return NULL;
    }

    MultiByteToWideChar(CP_UTF8, 0, s, -1, wide, length);

    return wide;
}

/* Appends arg to out, quoted so that CommandLineToArgvW reads it as one argument. Returns the length written. */
static size_t append_quoted(char *out, const char *arg)
{
    size_t n = 0;
    int needs_quotes = (arg[0] == 0);

    for (const char *p = arg; *p != 0; p++)
    {
        if (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\v' || *p == '"')
        {
            needs_quotes = 1;
            break;
        }
    }

    if (!needs_quotes)
    {
        size_t len = strlen(arg);
        memcpy(out, arg, len);
        return len;
    }

    out[n++] = '"';

    for (const char *p = arg;; p++)
    {
        size_t backslashes = 0;

        while (*p == '\\')
        {
            backslashes++;
            p++;
        }

        if (*p == 0)
        {
            /* backslashes before the closing quote are doubled */
            for (size_t i = 0; i < backslashes * 2; i++)
            {
                out[n++] = '\\';
            }
            break;
        }
        else if (*p == '"')
        {
            /* backslashes before a quote are doubled, and the quote is escaped */
            for (size_t i = 0; i < backslashes * 2 + 1; i++)
            {
                out[n++] = '\\';
            }
            out[n++] = '"';
        }
        else
        {
            for (size_t i = 0; i < backslashes; i++)
            {
                out[n++] = '\\';
            }
            out[n++] = *p;
        }
    }

    out[n++] = '"';

    return n;
}

/* Builds the command line. arguments is the argv passed from Dart, so index 0 is the executable itself: skip it. */
static LPWSTR build_command(char *executable, char **arguments)
{
    size_t capacity = 3; /* a pair of quotes + NUL */

    if (executable != NULL)
    {
        capacity += strlen(executable) * 2 + 3;
    }

    if (arguments != NULL)
    {
        for (int i = 1; arguments[i] != NULL; i++)
        {
            capacity += strlen(arguments[i]) * 2 + 3;
        }
    }

    char *line = malloc(capacity);

    if (line == NULL)
    {
        return NULL;
    }

    size_t n = 0;

    if (executable != NULL)
    {
        n += append_quoted(line + n, executable);
    }

    if (arguments != NULL)
    {
        for (int i = 1; arguments[i] != NULL; i++)
        {
            line[n++] = ' ';
            n += append_quoted(line + n, arguments[i]);
        }
    }

    line[n] = 0;

    LPWSTR command = utf8_to_wide(line);

    free(line);

    return command;
}

static LPWSTR build_environment(char **environment)
{
    size_t total = 0;

    if (environment != NULL)
    {
        for (int i = 0; environment[i] != NULL; i++)
        {
            int length = MultiByteToWideChar(CP_UTF8, 0, environment[i], -1, NULL, 0);

            if (length > 0)
            {
                total += (size_t)length; /* includes the terminating NUL */
            }
        }
    }

    LPWSTR block = malloc((total + 1) * sizeof(WCHAR));

    if (block == NULL)
    {
        return NULL;
    }

    size_t offset = 0;

    if (environment != NULL)
    {
        for (int i = 0; environment[i] != NULL; i++)
        {
            int length = MultiByteToWideChar(CP_UTF8, 0, environment[i], -1, NULL, 0);

            if (length > 0)
            {
                MultiByteToWideChar(CP_UTF8, 0, environment[i], -1, block + offset, length);
                offset += (size_t)length;
            }
        }
    }

    block[offset] = 0;

    return block;
}

static LPWSTR build_working_directory(char *working_directory)
{
    return utf8_to_wide(working_directory);
}

typedef struct ReadLoopOptions
{
    HANDLE fd;

    Dart_Port port;

    HANDLE hMutex;

    BOOL ackRead;

} ReadLoopOptions;

static DWORD WINAPI read_loop(LPVOID arg)
{
    ReadLoopOptions *options = (ReadLoopOptions *)arg;

    char buffer[1024];

    while (1)
    {
        DWORD readlen = 0;

        if (options->ackRead)
        {
            WaitForSingleObject(options->hMutex, INFINITE);
        }

        BOOL ok = ReadFile(options->fd, buffer, sizeof(buffer), &readlen, NULL);

        if (!ok)
        {
            break;
        }

        if (readlen <= 0)
        {
            break;
        }

        Dart_CObject result;
        result.type = Dart_CObject_kTypedData;
        result.value.as_typed_data.type = Dart_TypedData_kUint8;
        result.value.as_typed_data.length = readlen;
        result.value.as_typed_data.values = (uint8_t *)buffer;

        Dart_PostCObject_DL(options->port, &result);
    }

    return 0;
}

static void start_read_thread(HANDLE fd, Dart_Port port, HANDLE mutex, BOOL ackRead)
{
    ReadLoopOptions *options = malloc(sizeof(ReadLoopOptions));

    options->fd = fd;
    options->port = port;
    options->hMutex = mutex;
    options->ackRead = ackRead;

    DWORD thread_id;

    HANDLE thread = CreateThread(NULL, 0, read_loop, options, 0, &thread_id);

    if (thread == NULL)
    {
        free(options);
    }
}

typedef struct WaitExitOptions
{
    HANDLE pid;

    Dart_Port port;

    HANDLE hMutex;
} WaitExitOptions;

static DWORD WINAPI wait_exit_thread(LPVOID arg)
{
    WaitExitOptions *options = (WaitExitOptions *)arg;

    DWORD exit_code = 0;

    WaitForSingleObject(options->pid, INFINITE);

    GetExitCodeProcess(options->pid, &exit_code);

    CloseHandle(options->pid);
    CloseHandle(options->hMutex);

    Dart_PostInteger_DL(options->port, exit_code);

    return 0;
}

static void start_wait_exit_thread(HANDLE pid, Dart_Port port, HANDLE mutex)
{
    WaitExitOptions *options = malloc(sizeof(WaitExitOptions));

    options->pid = pid;
    options->port = port;
    options->hMutex = mutex;

    DWORD thread_id;

    HANDLE thread = CreateThread(NULL, 0, wait_exit_thread, options, 0, &thread_id);

    if (thread == NULL)
    {
        free(options);
    }
}

typedef struct PtyHandle
{
    PHANDLE inputWriteSide;

    PHANDLE outputReadSide;

    HPCON hPty;

    DWORD dwProcessId;

    BOOL ackRead;

    HANDLE hMutex;

} PtyHandle;

char *error_message = NULL;

FFI_PLUGIN_EXPORT PtyHandle *pty_create(PtyOptions *options)
{
    HANDLE inputReadSide = NULL;
    HANDLE inputWriteSide = NULL;

    HANDLE outputReadSide = NULL;
    HANDLE outputWriteSide = NULL;

    if (!CreatePipe(&inputReadSide, &inputWriteSide, NULL, 0))
    {
        error_message = "Failed to create input pipe";
        return NULL;
    }

    if (!CreatePipe(&outputReadSide, &outputWriteSide, NULL, 0))
    {
        error_message = "Failed to create output pipe";
        return NULL;
    }

    COORD size;

    size.X = options->cols;
    size.Y = options->rows;

    HPCON hPty;

    HRESULT result = CreatePseudoConsole(size, inputReadSide, outputWriteSide, 0, &hPty);

    if (FAILED(result))
    {
        error_message = "Failed to create pseudo console";
        return NULL;
    }

    STARTUPINFOEX startupInfo;

    ZeroMemory(&startupInfo, sizeof(startupInfo));
    startupInfo.StartupInfo.cb = sizeof(startupInfo);

    startupInfo.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startupInfo.StartupInfo.hStdInput = NULL;
    startupInfo.StartupInfo.hStdOutput = NULL;
    startupInfo.StartupInfo.hStdError = NULL;

    SIZE_T bytesRequired;
    InitializeProcThreadAttributeList(NULL, 1, 0, &bytesRequired);
    startupInfo.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)malloc(bytesRequired);

    BOOL ok = InitializeProcThreadAttributeList(startupInfo.lpAttributeList, 1, 0, &bytesRequired);

    if (!ok)
    {
        error_message = "Failed to initialize proc thread attribute list";
        return NULL;
    }

    ok = UpdateProcThreadAttribute(startupInfo.lpAttributeList,
                                   0,
                                   PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                                   hPty,
                                   sizeof(hPty),
                                   NULL,
                                   NULL);

    if (!ok)
    {
        error_message = "Failed to update proc thread attribute list";
        return NULL;
    }

    LPWSTR command = build_command(options->executable, options->arguments);

    LPWSTR environment_block = build_environment(options->environment);

    LPWSTR working_directory = build_working_directory(options->working_directory);

    PROCESS_INFORMATION processInfo;
    ZeroMemory(&processInfo, sizeof(processInfo));

    ok = CreateProcessW(NULL,
                        command,
                        NULL,
                        NULL,
                        FALSE,
                        EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
                        environment_block,
                        working_directory,
                        &startupInfo.StartupInfo,
                        &processInfo);

    if (command != NULL)
    {
        free(command);
    }

    if (environment_block != NULL)
    {
        free(environment_block);
    }

    if (working_directory != NULL)
    {
        free(working_directory);
    }

    if (!ok)
    {
        error_message = "Failed to create process";
        DWORD error = GetLastError();
        printf("error no: %d\n", error);
        return NULL;
    }

    // free(startupInfo.lpAttributeList);

    // CloseHandle(processInfo.hThread);

    HANDLE mutex = CreateSemaphore(
        NULL, // default security attributes
        1,    // initial count
        1,    // maximum count
        NULL);

    start_read_thread(outputReadSide, options->stdout_port, mutex, options->ackRead);

    start_wait_exit_thread(processInfo.hProcess, options->exit_port, mutex);

    PtyHandle *pty = malloc(sizeof(PtyHandle));

    if (pty == NULL)
    {
        error_message = "Failed to allocate pty handle";
        return NULL;
    }

    pty->inputWriteSide = inputWriteSide;
    pty->outputReadSide = outputReadSide;
    pty->hPty = hPty;
    pty->dwProcessId = processInfo.dwProcessId;
    pty->ackRead = options->ackRead;
    pty->hMutex = mutex;

    return pty;
}

FFI_PLUGIN_EXPORT void pty_write(PtyHandle *handle, char *buffer, int length)
{
    DWORD bytesWritten;

    WriteFile(handle->inputWriteSide, buffer, length, &bytesWritten, NULL);

    FlushFileBuffers(handle->inputWriteSide);

    return;
}

FFI_PLUGIN_EXPORT void pty_ack_read(PtyHandle *handle)
{
    if (handle->ackRead)
    {
        ReleaseSemaphore(handle->hMutex, 1, NULL);
    }
}

FFI_PLUGIN_EXPORT int pty_resize(PtyHandle *handle, int rows, int cols)
{
    COORD size;

    size.X = cols;
    size.Y = rows;

    return ResizePseudoConsole(handle->hPty, size);
}

FFI_PLUGIN_EXPORT int pty_getpid(PtyHandle *handle)
{
    return (int)handle->dwProcessId;
}

FFI_PLUGIN_EXPORT char *pty_error()
{
    return error_message;
}
