unit uStackTraceHelper;

interface

uses
  System.SysUtils;

type
  TStackTraceHelper = class
  public
    class procedure Initialize;
    class function CaptureExceptionStack(const E: Exception): string;
  end;

implementation

uses
  Winapi.Windows, System.Classes;

type
  ULONG = Cardinal;
  USHORT = Word;
  DWORD64 = UInt64;

  TRtlCaptureStackBackTrace = function(FramesToSkip, FramesToCapture: ULONG; BackTrace: PPointer;
    BackTraceHash: PULONG): USHORT; stdcall;

  PSYMBOL_INFO = ^SYMBOL_INFO;
  SYMBOL_INFO = record
    SizeOfStruct: ULONG;
    TypeIndex: ULONG;
    Reserved: array[0..1] of DWORD64;
    Index: ULONG;
    Size: ULONG;
    ModBase: DWORD64;
    Flags: ULONG;
    Value: DWORD64;
    Address: DWORD64;
    Register_: ULONG;
    Scope: ULONG;
    Tag: ULONG;
    NameLen: ULONG;
    MaxNameLen: ULONG;
    Name: array[0..0] of AnsiChar;
  end;

  TSymInitialize = function(hProcess: THandle; UserSearchPath: PAnsiChar; fInvadeProcess: BOOL): BOOL; stdcall;
  TSymCleanup = function(hProcess: THandle): BOOL; stdcall;
  TSymFromAddr = function(hProcess: THandle; Address: DWORD64; Displacement: PDWORD64; Symbol: PSYMBOL_INFO): BOOL; stdcall;
  TSymSetOptions = function(SymOptions: DWORD): DWORD; stdcall;

var
  GDbgHelp: HMODULE = 0;
  GSymInitialize: TSymInitialize = nil;
  GSymCleanup: TSymCleanup = nil;
  GSymFromAddr: TSymFromAddr = nil;
  GSymSetOptions: TSymSetOptions = nil;
  GSymbolsReady: Boolean = False;

function EnsureDbgHelp: Boolean;
var
  LProc: THandle;
begin
  Result := False;
  if GSymbolsReady then
    Exit(True);
  if GDbgHelp = 0 then
    GDbgHelp := LoadLibrary('dbghelp.dll');
  if GDbgHelp = 0 then
    Exit(False);
  Pointer(GSymInitialize) := GetProcAddress(GDbgHelp, 'SymInitialize');
  Pointer(GSymCleanup) := GetProcAddress(GDbgHelp, 'SymCleanup');
  Pointer(GSymFromAddr) := GetProcAddress(GDbgHelp, 'SymFromAddr');
  Pointer(GSymSetOptions) := GetProcAddress(GDbgHelp, 'SymSetOptions');
  if not Assigned(GSymInitialize) or not Assigned(GSymFromAddr) then
    Exit(False);
  LProc := GetCurrentProcess;
  if Assigned(GSymSetOptions) then
    GSymSetOptions($00000002 or $00000010);
  if GSymInitialize(LProc, nil, True) then
  begin
    GSymbolsReady := True;
    Result := True;
  end;
end;

function GetModuleAndOffset(const pAddress: Pointer; out pModuleName: string; out pOffsetHex: string): Boolean;
var
  LModule: HMODULE;
  LFileName: array[0..MAX_PATH] of Char;
  LBase: NativeUInt;
  LAddr: NativeUInt;
begin
  Result := False;
  pModuleName := '';
  pOffsetHex := '';
  LModule := 0;
  if not GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS or GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
    PChar(pAddress), LModule) then
    Exit(False);
  if GetModuleFileName(LModule, LFileName, MAX_PATH) = 0 then
    Exit(False);
  pModuleName := ExtractFileName(LFileName);
  LBase := NativeUInt(LModule);
  LAddr := NativeUInt(pAddress);
  if LAddr >= LBase then
    pOffsetHex := '0x' + IntToHex(LAddr - LBase, 8)
  else
    pOffsetHex := '0x' + IntToHex(LAddr, 8);
  Result := True;
end;

function ResolveSymbolName(const pAddress: Pointer; out pSymbol: string): Boolean;
const
  MaxSymName = 255;
var
  LProc: THandle;
  LDisp: DWORD64;
  LSymSize: Integer;
  LBuf: Pointer;
  LSym: PSYMBOL_INFO;
  LName: AnsiString;
begin
  Result := False;
  pSymbol := '';
  if not EnsureDbgHelp then
    Exit(False);
  LProc := GetCurrentProcess;
  LDisp := 0;
  LSymSize := SizeOf(SYMBOL_INFO) + MaxSymName + 1;
  GetMem(LBuf, LSymSize);
  try
    FillChar(LBuf^, LSymSize, 0);
    LSym := PSYMBOL_INFO(LBuf);
    LSym.SizeOfStruct := SizeOf(SYMBOL_INFO);
    LSym.MaxNameLen := MaxSymName;
    if Assigned(GSymFromAddr) and GSymFromAddr(LProc, DWORD64(NativeUInt(pAddress)), @LDisp, LSym) then
    begin
      SetString(LName, PAnsiChar(@LSym.Name[0]), LSym.NameLen);
      pSymbol := string(LName);
      if LDisp <> 0 then
        pSymbol := pSymbol + '+0x' + IntToHex(NativeUInt(LDisp), 1);
      Result := True;
    end;
  finally
    FreeMem(LBuf);
  end;
end;

function FormatFrame(const pAddress: Pointer): string;
var
  LModuleName: string;
  LOffsetHex: string;
  LSymbol: string;
  LAddrHex: string;
begin
  LAddrHex := '0x' + IntToHex(NativeUInt(pAddress), 8);
  if GetModuleAndOffset(pAddress, LModuleName, LOffsetHex) then
  begin
    if ResolveSymbolName(pAddress, LSymbol) then
      Result := LAddrHex + ' ' + LModuleName + ' ' + LOffsetHex + ' ' + LSymbol
    else
      Result := LAddrHex + ' ' + LModuleName + ' ' + LOffsetHex;
  end
  else
    Result := LAddrHex;
end;

class procedure TStackTraceHelper.Initialize;
begin
  try
    EnsureDbgHelp;
  except
  end;
end;

class function TStackTraceHelper.CaptureExceptionStack(const E: Exception): string;
var
  SL: TStringList;
  LRtlCapture: TRtlCaptureStackBackTrace;
  LKernel: HMODULE;
  LFrames: array[0..63] of Pointer;
  LCount: Integer;
  LIndex: Integer;
  LExceptAddr: Pointer;
begin
  Result := '';
  SL := TStringList.Create;
  try
    try
      if Assigned(E) then
      begin
        SL.Add(E.ClassName + ': ' + E.Message);
        LExceptAddr := ExceptAddr;
        if LExceptAddr <> nil then
          SL.Add('ExceptAddr=' + '0x' + IntToHex(NativeUInt(LExceptAddr), 8));
      end;
    except
    end;
    LKernel := GetModuleHandle('kernel32.dll');
    Pointer(LRtlCapture) := nil;
    if LKernel <> 0 then
      Pointer(LRtlCapture) := GetProcAddress(LKernel, 'RtlCaptureStackBackTrace');
    if Assigned(LRtlCapture) then
    begin
      LCount := LRtlCapture(2, Length(LFrames), @LFrames[0], nil);
      for LIndex := 0 to LCount - 1 do
        SL.Add(FormatFrame(LFrames[LIndex]));
    end;
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

end.
