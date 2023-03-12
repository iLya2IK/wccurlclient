unit wccurlclient;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  libpascurl,
  extmemorystream, fpjson, jsonparser, ECommonObjs;

type

  THTTP2BackgroundTask = class;
  THTTP2BackgroundTasks = class;

  TTaskNotify = procedure (aTask : THTTP2BackgroundTask) of object;
  TOnHTTP2Finish = TTaskNotify;
  TCURLNotifyEvent = procedure (aTask : THTTP2BackgroundTask; aObj : TJSONObject) of object;
  TCURLArrNotifyEvent = procedure (aTask : THTTP2BackgroundTask; aArr : TJSONArray) of object;
  TStringNotify = procedure (const aStr : String) of object;
  TConnNotifyEvent = procedure (aValue : Boolean) of object;
  TDataNotifyEvent = procedure (aData : TCustomMemoryStream) of object;

  { THTTP2SettingsIntf }

  THTTP2SettingsIntf = class(TThreadSafeObject)
  private
    FSID, FHost, FDevice, FMetaData : String;
    FProxyProtocol, FProxyHost, FProxyPort, FProxyUser, FProxyPwrd : String;
    FVerifyTSL : Boolean;
    function GetDevice : String;
    function GetHost : String;
    function GetMetaData : String;
    function GetSID : String;
    function GetProxyAddress : String;
    function GetProxyAuth : String;
    function GetVerifyTSL : Boolean;
    procedure SetDevice(const AValue : String);
    procedure SetHost(const AValue : String);
    procedure SetMetaData(AValue : String);
    procedure SetSID(const AValue : String);
    procedure SetProxyProt(const AValue : String);
    procedure SetProxyHost(const AValue : String);
    procedure SetProxyPort(const AValue : String);
    procedure SetProxyUser(const AValue : String);
    procedure SetProxyPwrd(const AValue : String);
    procedure SetVerifyTSL(AValue : Boolean);
  public
    constructor Create;
    property VerifyTSL : Boolean read GetVerifyTSL write SetVerifyTSL;
    property SID : String read GetSID write SetSID;
    property Host : String read GetHost write SetHost;
    property Device : String read GetDevice write SetDevice;
    property MetaData : String read GetMetaData write SetMetaData;
    property ProxyAddress : String read GetProxyAddress;
    property ProxyAuth : String read GetProxyAuth;
    procedure SetProxy(const aValue : String);
    function HasProxy : Boolean;
    function HasProxyAuth : Boolean;
    function HasProxyAuthPwrd : Boolean;
  end;

  { THTTP2BackgroundTask }

  THTTP2BackgroundTask = class(TThreadSafeObject)
  private
    FErrorBuffer : array [0 .. CURL_ERROR_SIZE] of char;
    FPath : String;
    FOnSuccess : TOnHTTP2Finish;
    FResponseCode : Longint;
    FErrorCode, FErrorSubCode : Longint;
    FPool : THTTP2BackgroundTasks;
    FCURL : CURL;
    FResponse : TMemoryStream;
    FRequest : TCustomMemoryStream;
    FOnFinish : TOnHTTP2Finish;
    FIsSilent : Boolean;
    headers : pcurl_slist;
    FState : Byte;
    FSettings : THTTP2SettingsIntf;
    FData : TObject;
    function GetErrorStr : String;
    function GetState : Byte;
    procedure SetState(aState : Byte);
    procedure Finalize;
    procedure AttachToPool;
    procedure DoError(err : Integer); overload;
    procedure DoError(err, subcode : Integer); overload;
    procedure ConfigCURL(aSz, aFSz : Int64; meth : Byte; isRead, isSeek : Boolean);
  public
    constructor Create(aPool : THTTP2BackgroundTasks; Settings : THTTP2SettingsIntf;
      aIsSilent : Boolean);
    destructor Destroy; override;
    function doPost(const aPath : String; aContent : Pointer;
      aContentSize : Int64; stack : Boolean) : Boolean;
    function Seek(offset: curl_off_t; origin: LongInt) : LongInt; virtual;
    function Write(ptr: Pointer; size: LongWord; nmemb: LongWord) : LongWord; virtual;
    function Read(ptr: Pointer; size: LongWord; nmemb: LongWord) : LongWord; virtual;

    procedure DoIdle; virtual;

    procedure Terminate;
    procedure Close; virtual;
    function Finished : Boolean;

    property OnFinish : TOnHTTP2Finish read FOnFinish write FOnFinish;
    property OnSuccess : TOnHTTP2Finish read FOnSuccess write FOnSuccess;

    property Path : String read FPath;
    property State : Byte read GetState write SetState;
    property IsSilent : Boolean read FIsSilent;
    property ResponseCode : Longint read FResponseCode;
    property ErrorCode : Longint read FErrorCode;
    property ErrorSubCode : Longint read FErrorSubCode;
    property ErrorString : String read GetErrorStr;

    property Request : TCustomMemoryStream read FRequest;
    property Response : TMemoryStream read FResponse;

    property Data : TObject read FData write FData;
  end;

  THTTP2BackgroundOutStreamTask = class;
  THTTP2BackgroundInStreamTask = class;

  TOnGetNextFrame = function (aTsk : THTTP2BackgroundOutStreamTask) : Integer of object;
  TOnHasNextFrame = procedure (aTsk : THTTP2BackgroundInStreamTask) of object;

  TMemSeq = specialize TThreadSafeFastBaseSeq<TCustomMemoryStream>;

  { THTTP2BackgroundOutStreamTask }

  THTTP2BackgroundOutStreamTask = class(THTTP2BackgroundTask)
  private
    FInc : integer;
    FFrames : TMemSeq;
    FOnGetNextFrame : TOnGetNextFrame;
    FSubProtocol : String;
    FDelta : Integer;
  protected
    procedure PopNextFrame;
  public
    constructor Create(aPool : THTTP2BackgroundTasks; Settings : THTTP2SettingsIntf;
      const aSubProto : String;
      aDelta : integer;
      aIsSilent : Boolean);
    destructor Destroy; override;

    function  Read(ptr: Pointer; size: LongWord; nmemb: LongWord) : LongWord; override;
    procedure LaunchStream(aOnGetNextFrame: TOnGetNextFrame);
    procedure PushFrame(aFrame : TCustomMemoryStream);

    procedure DoIdle; override;
  end;

  TWCRESTWebCamFrameState = (fstWaitingStartOfFrame, fstWaitingData);

  { THTTP2BackgroundInStreamTask }

  THTTP2BackgroundInStreamTask = class(THTTP2BackgroundTask)
  private
    FFrameBuffer : TExtMemoryStream;
    FFrameState  : TWCRESTWebCamFrameState;
    FFrameSize   : Cardinal;
    FFrameBufferSize : Cardinal;
    FFrameID : Integer;

    FFrames : TMemSeq;

    FDevice : String;
    FOnHasNextFrame : TOnHasNextFrame;
  protected
    procedure PushFrame(aStartAt : Int64);
    function TryConsumeFrame(Chunk : Pointer; ChunkSz : Integer) : integer;
  public
    constructor Create(aPool : THTTP2BackgroundTasks; Settings : THTTP2SettingsIntf;
      const aDevice : String;
      aIsSilent : Boolean);
    destructor Destroy; override;

    function Write(ptr: Pointer; size: LongWord; nmemb: LongWord) : LongWord; override;
    procedure LaunchStream(aOnHasNextFrame : TOnHasNextFrame);

    function PopFrame : TCustomMemoryStream;

    property Device : String read FDevice;

    procedure Close; override;

    procedure DoIdle; override;
  end;

  THTTP2StreamsTasks = specialize TThreadSafeFastBaseSeq<THTTP2BackgroundTask>;

  { TThreadsafeCURLM }

  TThreadsafeCURLM = class(TThreadSafeObject)
  private
    FValue : CURLM;
    function getValue : CURLM;
  public
    constructor Create;
    destructor Destroy; override;
    procedure InitCURLM;
    procedure DoneCURLM;
    property Value : CURLM read getValue;
  end;

  THTTP2BackgroundTasksProto = class (specialize TThreadSafeFastBaseSeq<THTTP2BackgroundTask>);

  { THTTP2BackgroundTasks }

  THTTP2BackgroundTasks = class (THTTP2BackgroundTasksProto)
  private
    FCURLM : TThreadsafeCURLM;
    FOnMultiError : TNotifyEvent;
    procedure IdleTask(aStrm : TObject);
    procedure TerminateTask(aStrm : TObject);
    function IsTaskFinished(aStrm : TObject; {%H-}data : pointer) : Boolean;
    procedure SetTaskFinished(aStrm : TObject; data : pointer);
    procedure SetMultiPollError(aStrm : TObject; data : pointer);
    procedure AfterTaskExtract(aStrm: TObject);
    procedure DoMultiError(code : integer);
    function DoInitMultiPipeling : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    property  CURLMv : TThreadsafeCURLM read FCURLM;
    procedure DoIdle;
    procedure Terminate;

    function Ready : Boolean;

    property OnMultiError : TNotifyEvent read FOnMultiError write FOnMultiError;
  end;

  { THTTP2AsyncBackground }

  THTTP2AsyncBackground = class(TThread)
  private
    FTasks : THTTP2BackgroundTasks;
  public
    constructor Create; overload;
    destructor Destroy; override;
    procedure Execute; override;
    procedure AddTask(aTask : THTTP2BackgroundTask);

    function Ready : Boolean;

    property Tasks : THTTP2BackgroundTasks read FTasks;
  end;

  { THTTP2StreamFrame }

  THTTP2StreamFrame = class(TThreadSafeObject)
  private
    FLstFrame : TCustomMemoryStream;
    FFrame : TCustomMemoryStream;
    FFrameID : integer;
    function GetFrame : TCustomMemoryStream;
    function GetFrameID : Integer;
    function GetLstFrame : TCustomMemoryStream;
  public
    constructor Create;
    destructor Destroy; override;

    function ExtractFrame : TCustomMemoryStream;
    procedure NextFrame(aBmp : TCustomMemoryStream);

    property Frame : TCustomMemoryStream read GetFrame;
    property LstFrame : TCustomMemoryStream read GetLstFrame;
    property FrameID : integer read GetFrameID;
  end;

  { TWCCURLClient }

  TWCCURLClient = class(TThreadSafeObject)
  private
    FSynchroFinishedTasks : THTTP2BackgroundTasksProto;
    FTaskPool : THTTP2AsyncBackground;
    FSetts : THTTP2SettingsIntf;
    FInitialized : Boolean;

    FFrame : THTTP2StreamFrame;
    FUpdates : THTTP2StreamsTasks;

    FLog : TThreadStringList;

    function DoInitMultiPipeling : Boolean;

  protected
    procedure SuccessAuth(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessDeleteRecords(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessGetConfig(ATask : THTTP2BackgroundTask); virtual;

    procedure SetConnected(AValue : Boolean); virtual;
    procedure SuccessRequestRecord(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessSaveAsSnapshot(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessSendMsg(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessUpdateDevices(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessUpdateMsgs(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessUpdateStreams(ATask : THTTP2BackgroundTask); virtual;
    procedure SuccessUpdateRecords(ATask : THTTP2BackgroundTask); virtual;
    procedure TaskFinished(ATask : THTTP2BackgroundTask); virtual;
    procedure SynchroFinishTasks; virtual;
    procedure SynchroUpdateTasks; virtual;

    procedure OnHasNextFrame(ATask : THTTP2BackgroundInStreamTask); virtual;
    procedure SuccessIOStream(ATask : THTTP2BackgroundTask); virtual;
    function  OnGetNextFrame(ATask : THTTP2BackgroundOutStreamTask) : integer; virtual;
    function  ConsumeResponseToObj(ATask : THTTP2BackgroundTask) : TJSONObject; virtual;
  private
    FConnected,
    FNeedToUpdateDevices,
    FNeedToUpdateRecords,
    FNeedToUpdateMsgs,
    FNeedToUpdateStreams,
    FStreaming : Boolean;
    FOnSuccessIOStream : TTaskNotify;
    FOnSynchroUpdateTask : TTaskNotify;
    FOnSuccessUpdateRecords : TCURLArrNotifyEvent;
    FOnDisconnect : TNotifyEvent;
    FOnAddLog : TStringNotify;
    FOnAfterLaunchInStream : TTaskNotify;
    FOnAfterLaunchOutStream : TTaskNotify;
    FOnSuccessUpdateDevices, FOnSuccessUpdateStreams : TCURLArrNotifyEvent;
    FOnSuccessUpdateMsgs : TCURLArrNotifyEvent;
    FOnSuccessSendMsg : TCURLNotifyEvent;
    FOnInitCURL : TNotifyEvent;
    FOnSuccessSaveAsSnapshot : TNotifyEvent;
    FOnSuccessRequestRecord : TDataNotifyEvent;
    FOnConnected : TConnNotifyEvent;
    FOnSuccessGetConfig : TCURLArrNotifyEvent;
    FOnSuccessDeleteRecords : TCURLNotifyEvent;
    FOnSuccessAuth : TCURLNotifyEvent;
    FOnSIDSetted : TStringNotify;
    LastMsgsStamp, LastRecsStamp : String;

    function GetConnected : Boolean;
    function GetDevice : String;
    function GetHost : String;
    function GetNeedToUpdateDevices : Boolean;
    function GetNeedToUpdateMsgs : Boolean;
    function GetNeedToUpdateRecords : Boolean;
    function GetNeedToUpdateStreams : Boolean;
    function GetProxy : String;
    function GetSID : String;
    function GetStreaming : Boolean;
    function GetVerifyTSL : Boolean;
    procedure SetNeedToUpdateDevices(AValue : Boolean);
    procedure SetNeedToUpdateMsgs(AValue : Boolean);
    procedure SetNeedToUpdateRecords(AValue : Boolean);
    procedure SetNeedToUpdateStreams(AValue : Boolean);
    procedure SetProxy(const AValue : String);
    procedure SetSID(const AValue : String);
    procedure SetStreaming(AValue : Boolean);
    procedure SetVerifyTSL(AValue : Boolean);
  public
    constructor Create;
    procedure Start;
    procedure TasksProceed; virtual;
    procedure Proceed; virtual;
    procedure Disconnect; virtual;
    destructor Destroy; override;

    procedure Authorize(const aName, aPass : String);
    function LaunchOutStream(const aSubProto : String; aDelta : integer) : Boolean;
    function LaunchInStream(const aDeviceName : String) : Boolean;
    procedure doPost(const aPath, aContent : String;
      OnSuccess : TOnHTTP2Finish; silent : Boolean = true);
    procedure doPost(const aPath : String; aContent : Pointer;
      aContentSize : Int64; OnSuccess : TOnHTTP2Finish; stack : boolean;
      silent : Boolean = true);

    procedure AddLog(const STR : String); virtual;

    function ExtractDeviceName(const dev : String) : String;

    procedure GetConfig;
    procedure SetConfig(const aStr : String);
    procedure UpdateDevices;
    procedure UpdateRecords;
    procedure UpdateMsgs;
    procedure UpdateStreams;
    procedure DeleteRecords(aIndices : TJSONArray);
    procedure SendMsg(aMsg : TJSONObject);
    procedure RequestRecord(rid : integer);
    procedure SaveAsSnapshot(Buf : Pointer;  Sz : Int64);

    property Log : TThreadStringList read FLog;

    property SID : String read GetSID write SetSID;
    property Host : String read GetHost;
    property Device : String read GetDevice;
    property VerifyTSL : Boolean read GetVerifyTSL write SetVerifyTSL;

    property OnInitCURL : TNotifyEvent read FOnInitCURL write FOnInitCURL;
    property OnConnectedChanged : TConnNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnect : TNotifyEvent read FOnDisconnect write FOnDisconnect;
    property OnAddLog : TStringNotify read FOnAddLog write FOnAddLog;
    property OnSuccessAuth : TCURLNotifyEvent read FOnSuccessAuth write FOnSuccessAuth;
    property OnSuccessUpdateDevices : TCURLArrNotifyEvent read FOnSuccessUpdateDevices write FOnSuccessUpdateDevices;
    property OnSuccessUpdateStreams : TCURLArrNotifyEvent read FOnSuccessUpdateStreams write FOnSuccessUpdateStreams;
    property OnSuccessUpdateMsgs : TCURLArrNotifyEvent read FOnSuccessUpdateMsgs write FOnSuccessUpdateMsgs;
    property OnSuccessUpdateRecords : TCURLArrNotifyEvent read FOnSuccessUpdateRecords write FOnSuccessUpdateRecords;
    property OnSuccessSendMsg : TCURLNotifyEvent read FOnSuccessSendMsg write FOnSuccessSendMsg;
    property OnSuccessDeleteRecords : TCURLNotifyEvent read FOnSuccessDeleteRecords write FOnSuccessDeleteRecords;
    property OnSuccessRequestRecord : TDataNotifyEvent read FOnSuccessRequestRecord write FOnSuccessRequestRecord;
    property OnSuccessSaveAsSnapshot : TNotifyEvent read FOnSuccessSaveAsSnapshot write FOnSuccessSaveAsSnapshot;
    property OnSuccessGetConfig : TCURLArrNotifyEvent read FOnSuccessGetConfig write FOnSuccessGetConfig;
    property OnAfterLaunchInStream : TTaskNotify read FOnAfterLaunchInStream write FOnAfterLaunchInStream;
    property OnAfterLaunchOutStream : TTaskNotify read FOnAfterLaunchOutStream write FOnAfterLaunchOutStream;
    property OnSIDSetted : TStringNotify read FOnSIDSetted write FOnSIDSetted;
    property OnSynchroUpdateTask : TTaskNotify read FOnSynchroUpdateTask write FOnSynchroUpdateTask;
    property OnSuccessIOStream : TTaskNotify read FOnSuccessIOStream write FOnSuccessIOStream;

    property Connected : Boolean read GetConnected write SetConnected;
    property IsStreaming : Boolean read GetStreaming write SetStreaming;
    property NeedToUpdateDevices : Boolean read GetNeedToUpdateDevices write SetNeedToUpdateDevices;
    property NeedToUpdateRecords : Boolean read GetNeedToUpdateRecords write SetNeedToUpdateRecords;
    property NeedToUpdateMsgs : Boolean read GetNeedToUpdateMsgs write SetNeedToUpdateMsgs;
    property NeedToUpdateStreams : Boolean read GetNeedToUpdateStreams write SetNeedToUpdateStreams;

    property Frame : THTTP2StreamFrame read FFrame;
    property Setts : THTTP2SettingsIntf read FSetts;
  end;


implementation

uses wcwebcamconsts;

function WriteFunctionCallback(ptr: Pointer; size: LongWord;
  nmemb: LongWord; data: Pointer): LongWord; cdecl;
begin
  Result := THTTP2BackgroundTask(data).Write(ptr, size, nmemb);
end;

function SeekFunctionCallback(ptr: Pointer; offset: curl_off_t;
  origin: LongInt): LongInt; cdecl;
begin
  Result := THTTP2BackgroundTask(ptr).Seek(offset, origin);
end;

function ReadFunctionCallback(ptr: Pointer; size: LongWord;
  nmemb: LongWord; data: Pointer): LongWord; cdecl;
begin
  Result := THTTP2BackgroundTask(data).Read(ptr, size, nmemb);
end;

function HTTPEncode(const AStr: String): String;

const
  HTTPAllowed = ['A'..'Z','a'..'z',
                 '*','@','.','_','-',
                 '0'..'9',
                 '$','!','''','(',')'];

var
  SS,S,R: PChar;
  H : String[2];
  L : Integer;

begin
  L:=Length(AStr);
  Result:='';
  if (L=0) then exit;

  SetLength(Result,L*3); // Worst case scenario
  R:=PChar(Result);
  S:=PChar(AStr);
  SS:=S; // Avoid #0 limit !!
  while ((S-SS)<L) do
    begin
    if S^ in HTTPAllowed then
      R^:=S^
    else if (S^=' ') then
      R^:='+'
    else
      begin
      R^:='%';
      H:=HexStr(Ord(S^),2);
      Inc(R);
      R^:=H[1];
      Inc(R);
      R^:=H[2];
      end;
    Inc(R);
    Inc(S);
    end;
  SetLength(Result,R-PChar(Result));
end;

{ TThreadsafeCURLM }

function TThreadsafeCURLM.getValue : CURLM;
begin
  Lock;
  try
    Result := FValue;
  finally
    UnLock;
  end;
end;

constructor TThreadsafeCURLM.Create;
begin
  inherited Create;
  FValue := nil;
end;

destructor TThreadsafeCURLM.Destroy;
begin
  DoneCURLM;
  inherited Destroy;
end;

procedure TThreadsafeCURLM.InitCURLM;
begin
  Lock;
  try
    FValue := curl_multi_init();
    if Assigned(FValue) then
      curl_multi_setopt(FValue, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX);
  finally
    UnLock;
  end;
end;

procedure TThreadsafeCURLM.DoneCURLM;
begin
  Lock;
  try
    if assigned(FValue) then
      curl_multi_cleanup(FValue);
    FValue := nil;
  finally
    UnLock;
  end;
end;

{ THTTP2BackgroundInStreamTask }

procedure THTTP2BackgroundInStreamTask.PushFrame(aStartAt : Int64);
var aFrame : TMemoryStream;
begin
  Lock;
  try
    Inc(FFrameID);
    aFrame := TMemoryStream.Create;
    FFrameBuffer.Position := aStartAt;
    aFrame.CopyFrom(FFrameBuffer, FFrameSize + WEBCAM_FRAME_HEADER_SIZE);
    aFrame.Position := 0;
    FFrames.Push_back(aFrame);
  finally
    UnLock;
  end;
end;

function THTTP2BackgroundInStreamTask.TryConsumeFrame(Chunk : Pointer;
  ChunkSz : Integer) : integer;
var BP : Int64;

procedure TruncateFrameBuffer;
begin
  if (BP > 0) then
  begin
    if ((FFrameBufferSize - BP) > 0) then
    begin
      FFrameBufferSize := FFrameBufferSize - BP;
      Move(Pointer(FFrameBuffer.Memory + BP)^,
           FFrameBuffer.Memory^, FFrameBufferSize);
    end else
      FFrameBufferSize := 0;
    BP := 0;
  end;
end;

function BufferFreeSize : Integer;
begin
  Result := WEBCAM_FRAME_BUFFER_SIZE - FFrameBufferSize;
end;

var W : Word;
    C : Cardinal;
    P : Int64;
begin
  BP := 0;
  Lock;
  try
    Result := 0;
    while true do
    begin
      if BufferFreeSize = 0 then
      begin
        DoError(ERR_WEBCAM_STREAM_BUFFER_OVERFLOW);
        Exit;
      end;

      if Result < ChunkSz then
      begin
        FFrameBuffer.Position := FFrameBufferSize;
        P := ChunkSz - Result;
        if P > BufferFreeSize then P := BufferFreeSize;
        FFrameBuffer.Write(Pointer(Chunk+Result)^, P);
        Inc(Result, P);
        FFrameBufferSize := FFrameBuffer.Position;
      end;

      FFrameBuffer.Position := BP;
      case FFrameState of
        fstWaitingStartOfFrame:
        begin
          FFrameSize := 0;
          if (FFrameBufferSize - BP) >= WEBCAM_FRAME_HEADER_SIZE then
          begin
            FFrameBuffer.Read(W, SizeOf(Word));
            if W = WEBCAM_FRAME_START_SEQ then
            begin
              FFrameBuffer.Read(C, SizeOf(Cardinal));
              if C > (WEBCAM_FRAME_BUFFER_SIZE - WEBCAM_FRAME_HEADER_SIZE) then
              begin
                DoError(ERR_WEBCAM_STREAM_FRAME_TO_BIG);
                Exit;
              end else
              begin
                FFrameSize := C;
                FFrameState := fstWaitingData;
              end;
            end else
            begin
              DoError(ERR_WEBCAM_STREAM_WRONG_HEADER);
              Exit;
            end;
          end else
          begin
            TruncateFrameBuffer;
            if Result >= ChunkSz then
              Exit;
          end;
        end;
        fstWaitingData:
        begin
          if (FFrameBufferSize - BP) >= (FFrameSize + WEBCAM_FRAME_HEADER_SIZE) then
          begin
            PushFrame(BP);
            Inc(BP, FFrameSize + WEBCAM_FRAME_HEADER_SIZE);
            FFrameState := fstWaitingStartOfFrame;
          end else
          begin
            FFrameState := fstWaitingStartOfFrame;
            TruncateFrameBuffer;
            if Result >= ChunkSz then
              Exit;
          end;
        end;
      end;
    end;
  finally
    UnLock;
  end;
end;

constructor THTTP2BackgroundInStreamTask.Create(aPool : THTTP2BackgroundTasks;
  Settings : THTTP2SettingsIntf; const aDevice : String; aIsSilent : Boolean);
begin
  inherited Create(aPool, Settings, aIsSilent);

  FDevice := aDevice;

  FreeAndNil(FResponse);

  FFrames := TMemSeq.Create;

  FFrameBuffer := TExtMemoryStream.Create(WEBCAM_FRAME_BUFFER_SIZE);
  FFrameState := fstWaitingStartOfFrame;
  FFrameBufferSize := 0;
  FFrameSize := 0;
  FFrameID := 0;
end;

destructor THTTP2BackgroundInStreamTask.Destroy;
begin
  FFrameBuffer.Free;
  FFrames.Clean;
  FFrames.Free;
  inherited Destroy;
end;

function THTTP2BackgroundInStreamTask.Write(ptr : Pointer; size : LongWord;
  nmemb : LongWord) : LongWord;
begin
  if Finished then Exit(0);

  Result := TryConsumeFrame(ptr, size * nmemb);

  if (FFrames.Count > 0) and Assigned(FOnHasNextFrame) then
    FOnHasNextFrame(Self);
end;

procedure THTTP2BackgroundInStreamTask.LaunchStream(
  aOnHasNextFrame : TOnHasNextFrame);
begin
  FOnHasNextFrame := aOnHasNextFrame;
  if FPool.Ready then
  begin
    FCURL := curl_easy_init;
    if Assigned(FCurl) then
    begin
      FPath := '/output.raw?' +cSHASH+'='+HTTPEncode(FSettings.SID) +
                                            '&'+cDEVICE+'='+HTTPEncode(FDevice);

      ConfigCURL(0, 0, METH_GET, false, false);
      curl_easy_setopt(FCURL, CURLOPT_TIMEOUT, Longint(-1));

      AttachToPool;
    end else
      DoError(TASK_ERROR_CANT_EASY_CURL);
  end;
end;

function THTTP2BackgroundInStreamTask.PopFrame : TCustomMemoryStream;
begin
  Result := FFrames.PopValue;
end;

procedure THTTP2BackgroundInStreamTask.Close;
begin
  Lock;
  try
    Data := nil;
  finally
    UnLock;
  end;
  inherited Close;
end;

procedure THTTP2BackgroundInStreamTask.DoIdle;
begin
  //inherited DoIdle;
  if (FFrames.Count > 0) and Assigned(FOnHasNextFrame) then
    FOnHasNextFrame(Self);
end;

{ THTTP2StreamFrame }

function THTTP2StreamFrame.GetFrame : TCustomMemoryStream;
begin
  Lock;
  try
    Result := FFrame;
  finally
    UnLock;
  end;
end;

function THTTP2StreamFrame.GetFrameID : Integer;
begin
  Lock;
  try
    Result := FFrameID;
  finally
    UnLock;
  end;
end;

function THTTP2StreamFrame.GetLstFrame : TCustomMemoryStream;
begin
  Lock;
  try
    Result := FLstFrame;
  finally
    UnLock;
  end;
end;

constructor THTTP2StreamFrame.Create;
begin
  inherited Create;
  FFrame := nil;
  FLstFrame := nil;
  FFrameID := 0;
end;

destructor THTTP2StreamFrame.Destroy;
begin
  if assigned(FFrame) then FreeAndNil(FFrame);
  if assigned(FLstFrame) then FreeAndNil(FLstFrame);
  inherited Destroy;
end;

function THTTP2StreamFrame.ExtractFrame : TCustomMemoryStream;
begin
  Lock;
  try
    Result := FFrame;
    FFrame := nil;
  finally
    UnLock;
  end;
end;

procedure THTTP2StreamFrame.NextFrame(aBmp : TCustomMemoryStream);
begin
  Lock;
  try
    Inc(FFrameID);
    if assigned(FLstFrame) then FreeAndNil(FLstFrame);
    FLstFrame := TMemoryStream.Create;
    FLstFrame.CopyFrom(aBmp, aBmp.Size);
    aBmp.Position := 0;
    FFrame := aBmp;
  finally
    UnLock;
  end;
end;

{ THTTP2BackgroundOutStreamTask }

procedure THTTP2BackgroundOutStreamTask.PushFrame(aFrame : TCustomMemoryStream);
begin
  if assigned(aFrame) then
   FFrames.Push_back(aFrame);
end;

procedure THTTP2BackgroundOutStreamTask.PopNextFrame;
var Fr : TCustomMemoryStream;
begin
  Fr := FFrames.PopValue;
  if Assigned(Fr) then
  begin
    if Assigned(FRequest) then FRequest.Free;
    FRequest := Fr;
  end;
end;

constructor THTTP2BackgroundOutStreamTask.Create(aPool : THTTP2BackgroundTasks;
  Settings : THTTP2SettingsIntf; const aSubProto : String; aDelta : integer;
  aIsSilent : Boolean);
begin
  inherited Create(aPool, Settings, aIsSilent);
  FFrames := TMemSeq.Create;
  FInc := 0;
  FSubProtocol := aSubProto;
  FDelta := aDelta;
end;

destructor THTTP2BackgroundOutStreamTask.Destroy;
begin
  FFrames.Free;
  inherited Destroy;
end;

function THTTP2BackgroundOutStreamTask.Read(ptr : Pointer; size : LongWord;
  nmemb : LongWord) : LongWord;

function DoRead : LongWord;
begin
  if assigned(Request) and (Request.Size > 0) then
  begin
    Result := Request.Read(ptr^, nmemb * size);
  end else
    Result := 0;
end;

begin
  if Finished then Exit(CURL_READFUNC_ABORT);

  Lock;
  try
    Result := DoRead;
    if Result = 0 then
    begin
      PopNextFrame;
      Result := DoRead;
    end;
  finally
    UnLock;
  end;

  if Result = 0 then
    Result := CURL_READFUNC_PAUSE;
end;

procedure THTTP2BackgroundOutStreamTask.LaunchStream(aOnGetNextFrame : TOnGetNextFrame);
begin
  FOnGetNextFrame := aOnGetNextFrame;
  if FPool.Ready then
  begin
    FCURL := curl_easy_init;
    if Assigned(FCurl) then
    begin
      FResponse.Position := 0;
      FResponse.Size := 0;
      FPath := '/input.raw?' +cSHASH+'='+HTTPEncode(FSettings.SID);
      if Length(FSubProtocol) > 0 then
         FPath := FPath + '&' + cSUBPROTO + '=' + HTTPEncode(FSubProtocol);
      if FDelta > 0 then
         FPath := FPath + '&' + cDELTA + '=' + IntToStr(FDelta);

      ConfigCURL($500000000, -1, METH_UPLOAD, True, True);

      FRequest := TMemoryStream.Create;
      FRequest.Position := 0;

      AttachToPool;
    end else
      DoError(TASK_ERROR_CANT_EASY_CURL);
  end;
end;

procedure THTTP2BackgroundOutStreamTask.DoIdle;
var fr : integer;
begin
  Lock;
  try
    fr := FOnGetNextFrame(Self);
  finally
    UnLock;
  end;
  if fr > 0 then
  begin
    fr := integer(curl_easy_pause(FCURL, CURLPAUSE_CONT));
    if fr <> integer(CURLE_OK) then
      DoError(TASK_ERROR_CURL, fr);
  end;
end;

{ THTTP2AsyncBackground }

constructor THTTP2AsyncBackground.Create;
begin
  inherited Create(true);
  FreeOnTerminate := false;
  FTasks := THTTP2BackgroundTasks.Create;
end;

destructor THTTP2AsyncBackground.Destroy;
begin
  FTasks.Free;
  inherited Destroy;
end;

procedure THTTP2AsyncBackground.Execute;
begin
  while not Terminated do
  begin
    Tasks.DoIdle;
    Sleep(100);
  end;
  Tasks.Terminate;
end;

procedure THTTP2AsyncBackground.AddTask(aTask : THTTP2BackgroundTask);
begin
  FTasks.Push_back(aTask);
end;

function THTTP2AsyncBackground.Ready : Boolean;
begin
  Result := Tasks.Ready;
end;

{ THTTP2SettingsIntf }

function THTTP2SettingsIntf.GetDevice : String;
begin
  Lock;
  try
    Result := FDevice;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.GetHost : String;
begin
  Lock;
  try
    Result := FHost;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.GetMetaData : String;
begin
  Lock;
  try
    Result := FMetaData;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.GetSID : String;
begin
  Lock;
  try
    Result := FSID;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.GetProxyAddress : String;
begin
  Lock;
  try
    Result := FProxyProtocol + FProxyHost;
    if Length(FProxyPort) > 0 then
       Result := Result + ':' + FProxyPort;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.GetProxyAuth : String;
begin
  Lock;
  try
    Result := FProxyUser;
    if Length(FProxyPwrd) > 0 then
       Result := Result + ':' + FProxyPwrd;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.GetVerifyTSL : Boolean;
begin
  Lock;
  try
    Result := FVerifyTSL;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetDevice(const AValue : String);
begin
  Lock;
  try
    FDevice := AValue;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetHost(const AValue : String);
begin
  Lock;
  try
    FHost := AValue;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetMetaData(AValue : String);
begin
  Lock;
  try
    FMetaData := AValue;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetSID(const AValue : String);
begin
  Lock;
  try
    FSID := AValue;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetProxyProt(const AValue : String);
begin
  Lock;
  try
    FProxyProtocol := AValue;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetProxyHost(const AValue : String);
begin
  Lock;
  try
    FProxyHost := AValue;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetProxyPort(const AValue : String);
begin
  Lock;
  try
    FProxyPort := AValue;
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetProxyUser(const AValue : String);
begin
  Lock;
  try
    FProxyUser := HTTPEncode(AValue);
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetProxyPwrd(const AValue : String);
begin
  Lock;
  try
    FProxyPwrd := HTTPEncode(AValue);
  finally
    UnLock;
  end;
end;

procedure THTTP2SettingsIntf.SetVerifyTSL(AValue : Boolean);
begin
  Lock;
  try
    FVerifyTSL := AValue;
  finally
    UnLock;
  end;
end;

constructor THTTP2SettingsIntf.Create;
begin
  inherited Create;
  FProxyProtocol := 'http://';
end;

procedure THTTP2SettingsIntf.SetProxy(const aValue : String);
var
  S, SS, R : PChar;
  Res : PChar;
  SL : TStringList;
  UP, address_len : Integer;
  L : Integer;
begin
  Lock;
  try
    if Length(AValue) > 0 then
    begin
      FProxyPwrd := '';
      FProxyPort := '';
      FProxyUser := '';
      FProxyHost := '';
      Exit;
    end;

    S := PChar(@(aValue[1]));
    SS := S;
    L := Length(S);
    Res := GetMem(L+1);
    try
      R := Res;
      UP := 0;
      SL := TStringList.Create;
      try
        while ((SS - S) < L) do
        begin
          if (SS^ in [':', '@']) then
          begin
            R^ := #0;
            SL.Add(StrPas(Res));
            R := Res;
            if SS^ = '@' then UP := SL.Count;
          end else
          begin
            R^ := SS^;
            Inc(R);
          end;
          Inc(SS);
        end;
        if (R > Res) then
        begin
          R^ := #0;
          SL.Add(StrPas(Res));
        end;

        case UP of
          1 : begin
            FProxyUser := SL[0];
            FProxyPwrd := '';
          end;
          2 : begin
            FProxyUser := SL[0];
            FProxyPwrd := SL[1];
          end;
        else
          FProxyUser := '';
          FProxyPwrd := '';
        end;

        address_len := SL.Count - UP;

        case (address_len) of
        1 : begin
                FProxyHost := SL[SL.Count-1];
                FProxyPort := '';
            end;
        2, 3 : begin
                if (TryStrToInt(SL[SL.Count-1], L)) then
                begin
                    FProxyPort := SL[SL.Count-1];
                    dec(address_len);
                end else begin
                    FProxyPort := '';
                end;
                if (address_len > 1) then begin
                    FProxyProtocol := SL[UP] + '://';
                    FProxyHost := SL[UP+1];
                    while ((Length(FProxyHost) > 0) and (FProxyHost[1] = '/')) do
                        Delete(FProxyHost, 1, 1);
                end else begin
                    FProxyHost := SL[UP];
                end;
            end;
        else
            FProxyHost := '';
            FProxyPort := '';
        end;

      finally
        SL.Free;
      end;
    finally
      FreeMem(Res);
    end;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.HasProxy : Boolean;
begin
  Lock;
  try
    Result := Length(FProxyHost) > 0;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.HasProxyAuth : Boolean;
begin
  Lock;
  try
    Result := Length(FProxyUser) > 0;
  finally
    UnLock;
  end;
end;

function THTTP2SettingsIntf.HasProxyAuthPwrd : Boolean;
begin
  Lock;
  try
    Result := Length(FProxyPwrd) > 0;
  finally
    UnLock;
  end;
end;

{ THTTP2BackgroundTask }

function THTTP2BackgroundTask.GetState : Byte;
begin
  Lock;
  try
    Result := FState;
  finally
    UnLock;
  end;
end;

function THTTP2BackgroundTask.GetErrorStr : String;
begin
  Result := StrPas(FErrorBuffer);
end;

procedure THTTP2BackgroundTask.SetState(aState : Byte);
begin
  Lock;
  try
    FState := aState;
  finally
    UnLock;
  end;
end;

procedure THTTP2BackgroundTask.Finalize;
begin
  if Assigned(FCURL) then
  begin
    FPool.CURLMv.Lock;
    try
      try
        curl_multi_remove_handle(FPool.CURLMv.FValue, FCURL);
      except
        //do nothing
      end;
    finally
      FPool.CURLMv.UnLock;
    end;
    if Assigned(headers) then
      curl_slist_free_all(headers);
    curl_easy_cleanup(FCURL);
    FCURL := nil;
  end;
end;

procedure THTTP2BackgroundTask.AttachToPool;
begin
  FPool.CURLMv.Lock;
  try
    FErrorSubCode := Integer(curl_multi_add_handle(FPool.CURLMv.FValue, FCURL));
    if FErrorSubCode <> Integer( CURLE_OK ) then
      DoError(TASK_ERROR_ATTACH_REQ, FErrorSubCode);
  finally
    FPool.CURLMv.UnLock;
  end;
end;

procedure THTTP2BackgroundTask.DoError(err : Integer);
begin
  DoError(err, 0);
end;

procedure THTTP2BackgroundTask.DoError(err, subcode : Integer);
begin
  Lock;
  try
    FErrorCode := err;
    FErrorSubCode := subcode;
  finally
    UnLock;
  end;
  State := STATE_FINISHED;
end;

procedure THTTP2BackgroundTask.ConfigCURL(aSz, aFSz : Int64; meth : Byte;
  isRead, isSeek : Boolean);
begin
  curl_easy_setopt(FCURL, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
  curl_easy_setopt(FCURL, CURLOPT_URL, PChar(FSettings.Host + FPath));
  case meth of
    METH_POST: curl_easy_setopt(FCURL, CURLOPT_POST, Longint(1));
    METH_UPLOAD: curl_easy_setopt(FCURL, CURLOPT_UPLOAD, Longint(1));
  end;

  if not FSettings.VerifyTSL then
  begin
    curl_easy_setopt(FCURL, CURLOPT_SSL_VERIFYPEER, Longint(0));
    curl_easy_setopt(FCURL, CURLOPT_SSL_VERIFYHOST, Longint(0));
  end;

  if FSettings.HasProxy then
  begin
   curl_easy_setopt(FCURL, CURLOPT_PROXY, PChar(FSettings.ProxyAddress));
    if  FSettings.HasProxyAuth then
    begin
      curl_easy_setopt(FCURL, CURLOPT_PROXYAUTH, CURLAUTH_ANYSAFE);
      if  FSettings.HasProxyAuthPwrd then
        curl_easy_setopt(FCURL, CURLOPT_PROXYUSERPWD, PChar(FSettings.ProxyAuth)) else
        curl_easy_setopt(FCURL, CURLOPT_PROXYUSERNAME, PChar(FSettings.ProxyAuth));
    end;
  end;

  curl_easy_setopt(FCURL, CURLOPT_WRITEDATA, Pointer(Self));
  curl_easy_setopt(FCURL, CURLOPT_WRITEFUNCTION, @WriteFunctionCallback);
  headers := nil;
  headers := curl_slist_append(headers, Pchar('content-length: ' + inttostr(aSz)));
  curl_easy_setopt(FCURL, CURLOPT_HTTPHEADER, headers);
  curl_easy_setopt(FCURL, CURLOPT_PIPEWAIT, Longint(1));
  curl_easy_setopt(FCURL, CURLOPT_NOSIGNAL, Longint(1));

  if isSeek then begin
     curl_easy_setopt(FCURL, CURLOPT_SEEKDATA, Pointer(Self));
     curl_easy_setopt(FCURL, CURLOPT_SEEKFUNCTION,  @SeekFunctionCallback);
  end;

  if isRead then begin
     curl_easy_setopt(FCURL, CURLOPT_READDATA, Pointer(Self));
     curl_easy_setopt(FCURL, CURLOPT_READFUNCTION,  @ReadFunctionCallback);
     curl_easy_setopt(FCURL, CURLOPT_INFILESIZE, Longint(aFSz));
     curl_easy_setopt(FCURL, CURLOPT_INFILESIZE_LARGE, Int64(aFSz));
  end;

  curl_easy_setopt(FCURL, CURLOPT_ERRORBUFFER, PChar(FErrorBuffer));
  FillChar(FErrorBuffer, CURL_ERROR_SIZE, #0);
end;

constructor THTTP2BackgroundTask.Create(aPool : THTTP2BackgroundTasks;
  Settings : THTTP2SettingsIntf; aIsSilent : Boolean);
begin
  inherited Create;
  FCURL := nil;
  FPool := aPool;
  FSettings := Settings;
  FErrorCode := TASK_NO_ERROR;
  FErrorSubCode := 0;
  FState := STATE_INIT;
  FIsSilent := aIsSilent;

  FResponse := TMemoryStream.Create;
  FRequest := nil;
end;

destructor THTTP2BackgroundTask.Destroy;
begin
  Finalize;
  if Assigned(FResponse) then  FResponse.Free;
  if Assigned(FRequest) then  FRequest.Free;
  inherited Destroy;
end;

function THTTP2BackgroundTask.doPost(const aPath : String;
  aContent : Pointer; aContentSize : Int64; stack : Boolean) : Boolean;
begin
  Result := false;

  if FPool.Ready then
  begin
    FCURL := curl_easy_init;
    if Assigned(FCurl) then
    begin
      FResponse.Position := 0;
      FResponse.Size := 0;
      FPath := aPath;
      ConfigCURL(aContentSize, aContentSize, METH_POST, (aContentSize > 0), false);

      if (aContentSize > 0) then begin
        if stack then
        begin
          FRequest := TMemoryStream.Create;
          FRequest.Write(aContent^,  aContentSize);
          FRequest.Position := 0;
        end else
        begin
          FRequest := TExtMemoryStream.Create;
          TExtMemoryStream(FRequest).SetPtr(aContent,  aContentSize);
        end;
      end;

      AttachToPool;
      Result := true;
    end else
      DoError(TASK_ERROR_CANT_EASY_CURL);
  end;
end;

function THTTP2BackgroundTask.Seek(offset : curl_off_t; origin : LongInt
  ) : LongInt;
var origin_v : TSeekOrigin;
begin
  Lock;
  try
    case origin of
      0 : origin_v := soBeginning;
      1 : origin_v := soCurrent;
      2 : origin_v := soEnd;
    end;
    FRequest.Seek(offset, origin_v);

    Result := CURL_SEEKFUNC_OK;
  finally
    UnLock;
  end;
end;

function THTTP2BackgroundTask.Write(ptr : Pointer; size : LongWord; nmemb : LongWord
  ) : LongWord;
begin
  if Finished then Exit(0);

  Result := FResponse.Write(ptr^, size * nmemb);
end;

function THTTP2BackgroundTask.Read(ptr : Pointer; size : LongWord; nmemb : LongWord
  ) : LongWord;
begin
  if Finished then Exit(CURL_READFUNC_ABORT);

  if assigned(FRequest) then
    Result := FRequest.Read(ptr^, nmemb * size) else
    Result := 0;
end;

procedure THTTP2BackgroundTask.DoIdle;
begin
  //
end;

procedure THTTP2BackgroundTask.Terminate;
begin
  State := STATE_TERMINATED;
end;

procedure THTTP2BackgroundTask.Close;
begin
  Terminate;
end;

function THTTP2BackgroundTask.Finished : Boolean;
begin
  Lock;
  try
    Result := FState >= STATE_FINISHED;
  finally
    UnLock;
  end;
end;

{ THTTP2BackgroundTasks }

function THTTP2BackgroundTasks.IsTaskFinished(aStrm : TObject; {%H-}data : pointer
  ) : Boolean;
begin
  Result := THTTP2BackgroundTask(aStrm).Finished;
end;

procedure THTTP2BackgroundTasks.SetTaskFinished(aStrm : TObject; data : pointer
  );
var rc, sb : integer;
begin
  if THTTP2BackgroundTask(aStrm).FCURL = pCURLMsg_rec(data)^.easy_handle then
  begin
    THTTP2BackgroundTask(aStrm).State := STATE_FINISHED;
    if pCURLMsg_rec(data)^.result <> CURLE_OK then
    begin
      THTTP2BackgroundTask(aStrm).DoError(TASK_ERROR_CURL,
                                          integer(pCURLMsg_rec(data)^.result));
    end else
    begin
      sb := Longint(curl_easy_getinfo(pCURLMsg_rec(data)^.easy_handle,
                                                 CURLINFO_RESPONSE_CODE,
                                                 @rc));
      if sb = Longint(CURLE_OK) then
        THTTP2BackgroundTask(aStrm).FResponseCode := rc
      else
        THTTP2BackgroundTask(aStrm).DoError(TASK_ERROR_GET_INFO, sb);
    end;
  end;
end;

procedure THTTP2BackgroundTasks.SetMultiPollError(aStrm : TObject;
  data : pointer);
begin
  THTTP2BackgroundTask(aStrm).DoError(TASK_ERROR_CURL, pInteger(data)^);
end;

procedure THTTP2BackgroundTasks.IdleTask(aStrm : TObject);
begin
  THTTP2BackgroundTask(aStrm).DoIdle;
end;

procedure THTTP2BackgroundTasks.TerminateTask(aStrm : TObject);
begin
  THTTP2BackgroundTask(aStrm).Terminate;
end;

procedure THTTP2BackgroundTasks.AfterTaskExtract(aStrm : TObject);
begin
  if assigned(THTTP2BackgroundTask(aStrm).OnFinish) then
    THTTP2BackgroundTask(aStrm).OnFinish(THTTP2BackgroundTask(aStrm)) else
    aStrm.Free;
end;

procedure THTTP2BackgroundTasks.DoMultiError(code : integer);
begin
  DoForAllEx(@SetMultiPollError, @code);
  Lock;
  try
    if Assigned(FCURLM) then
      FreeAndNil(FCURLM);
  finally
    UnLock;
  end;
  if assigned(OnMultiError) then
    OnMultiError(Self);
end;

function THTTP2BackgroundTasks.DoInitMultiPipeling : Boolean;
begin
  CURLMv.Lock;
  try
    if Assigned(CURLMv.FValue) then Exit(true);
    CURLMv.InitCURLM;

    Result := Assigned(CURLMv.FValue);
  finally
    CURLMv.UnLock;
  end;
end;

constructor THTTP2BackgroundTasks.Create;
begin
  inherited Create;
  FCURLM := TThreadsafeCURLM.Create;
  FOnMultiError := nil;
end;

destructor THTTP2BackgroundTasks.Destroy;
begin
  inherited Destroy;
  if Assigned(FCURLM) then FCURLM.Free;
end;

procedure THTTP2BackgroundTasks.DoIdle;
var response_code, still_running, msgq : integer;
    m : pCURLMsg_rec;
begin
  try
    CURLMv.Lock;
    try
      if Ready then
      begin
        response_code := Integer(curl_multi_perform(CURLMv.FValue, @still_running));

        if (response_code = Integer( CURLE_OK )) then
        begin
         repeat
           m := curl_multi_info_read(CURLMv.FValue, @msgq);
           if (assigned(m) and (m^.msg = CURLMSG_DONE)) then
             DoForAllEx(@SetTaskFinished, m);
         until not Assigned(m);

         if (still_running > 0) then
           response_code := Integer(curl_multi_poll(CURLMv.FValue, [], 0, 200, nil));
        end;
      end else
        response_code := 0;
    finally
      CURLMv.UnLock;
    end;
  except
    response_code := -1;
  end;
  if (response_code <> Integer( CURLE_OK )) then
    DoMultiError(response_code);

  DoForAll(@IdleTask);
  ExtractObjectsByCriteria(@IsTaskFinished, @AfterTaskExtract, nil);
end;

procedure THTTP2BackgroundTasks.Terminate;
begin
  DoForAll(@TerminateTask);
end;

function THTTP2BackgroundTasks.Ready : Boolean;
begin
  Result := Assigned(CURLMv.FValue);
end;

{ TWCCURLClient }

function TWCCURLClient.DoInitMultiPipeling : Boolean;
begin
  Result := FTaskPool.Tasks.DoInitMultiPipeling;

  if Result then
  begin
    if (not FInitialized) and Assigned(OnInitCURL) then
      OnInitCURL(FTaskPool.Tasks);

    FInitialized := true;
  end else FInitialized := false;
end;

procedure TWCCURLClient.SuccessAuth(ATask : THTTP2BackgroundTask);
var
  jObj : TJSONObject;
  jData : TJSONData;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);
    if Assigned(jObj) then
    begin
      if jObj.Find(cSHASH, jData) then
      begin
        SID := jData.AsString;

        Connected := true;
        NeedToUpdateDevices := true;
        NeedToUpdateRecords := true;
        NeedToUpdateMsgs    := true;
        NeedToUpdateStreams := true;
        if Assigned(OnSuccessAuth) then
          OnSuccessAuth(ATask, jObj);
      end;
      FreeAndNil(jObj);
    end;
  end else
      Disconnect;
end;

procedure TWCCURLClient.SuccessDeleteRecords(ATask : THTTP2BackgroundTask);
var
  jObj : TJSONObject;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);

    if Assigned(OnSuccessDeleteRecords) then
      OnSuccessDeleteRecords(ATask, jObj);

    if Assigned(jObj) then
      FreeAndNil(jObj);
  end else
    Disconnect;
end;

procedure TWCCURLClient.SuccessGetConfig(ATask : THTTP2BackgroundTask);
var
  jObj : TJSONObject;
  jArr : TJSONArray;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);
    if Assigned(jObj) then
    begin
      try
        if jObj.Find(cCONFIG, jArr) then
        begin
          if Assigned(OnSuccessGetConfig) then
            OnSuccessGetConfig(ATask, jArr);
        end;
      finally
        jObj.Free;
      end;
    end;
  end else
    Disconnect;
end;

procedure TWCCURLClient.SetConnected(AValue : Boolean);
begin
  Lock;
  try
    if FConnected = AValue then Exit;
    FConnected := AValue;
  finally
    UnLock;
  end;

  if Assigned(OnConnectedChanged) then
    OnConnectedChanged(AValue);
end;

procedure TWCCURLClient.SuccessRequestRecord(ATask : THTTP2BackgroundTask);
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    ATask.FResponse.Position := 0;
    if Assigned(OnSuccessRequestRecord) then
      OnSuccessRequestRecord(ATask.FResponse);
  end else
    Disconnect;
end;

procedure TWCCURLClient.SuccessSaveAsSnapshot(ATask : THTTP2BackgroundTask);
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    if Assigned(OnSuccessSaveAsSnapshot) then
      OnSuccessSaveAsSnapshot(ATask);
  end else
    Disconnect;
end;

procedure TWCCURLClient.SuccessSendMsg(ATask : THTTP2BackgroundTask);
var
  jObj : TJSONObject;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);
    if Assigned(jObj) then
    begin
      if Assigned(OnSuccessSendMsg) then
        OnSuccessSendMsg(ATask, jObj);

      FreeAndNil(jObj);
    end;
  end else
    Disconnect;
end;

procedure TWCCURLClient.SuccessUpdateDevices(ATask : THTTP2BackgroundTask);
var
  jObj : TJSONObject;
  jArr : TJSONArray;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);
    if Assigned(jObj) then
    begin
      jArr := TJSONArray(jObj.Find(cDEVICES));
      if Assigned(jArr) then
      begin
        if Assigned(OnSuccessUpdateDevices) then
          OnSuccessUpdateDevices(ATask, jArr);
      end;
      FreeAndNil(jObj);
    end else
      Disconnect;
  end else
    Disconnect;
end;

procedure TWCCURLClient.SuccessUpdateMsgs(ATask : THTTP2BackgroundTask);
var i, n : integer;
  jObj, jEl : TJSONObject;
  jArr : TJSONArray;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);
    if Assigned(jObj) then
    try
      jArr := TJSONArray(jObj.Find(cMSGS));
      if assigned(jArr) then
      begin
        if Assigned(OnSuccessUpdateMsgs) then
          OnSuccessUpdateMsgs(ATask, jArr);
        if jArr.Count > 0 then
        begin
          for i := 0 to jArr.Count-1 do
          begin
            jEl := TJSONObject(jArr[i]);
            for n := 0 to jEl.Count-1 do
            begin
              if SameText(cSTAMP, jEl.Names[n]) then begin
                LastMsgsStamp := jEl.Items[n].AsString;
                break;
              end;
            end;
          end;
        end;
      end;
    finally
      jObj.Free;
    end;
  end else
    Disconnect;
end;

procedure TWCCURLClient.SuccessUpdateStreams(ATask : THTTP2BackgroundTask);
var
  jObj : TJSONObject;
  jArr : TJSONArray;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);
    if Assigned(jObj) then
    begin
      jArr := TJSONArray(jObj.Find(cDEVICES));
      if Assigned(jArr) then
      begin
        if Assigned(OnSuccessUpdateStreams) then
          OnSuccessUpdateStreams(ATask, jArr);
      end;
      FreeAndNil(jObj);
    end else
      Disconnect;
  end else
    Disconnect;
end;

procedure TWCCURLClient.SuccessUpdateRecords(ATask : THTTP2BackgroundTask);
var i, n : integer;
  jObj, jEl : TJSONObject;
  jArr : TJSONArray;
begin
  if ATask.ErrorCode = TASK_NO_ERROR then
  begin
    jObj := ConsumeResponseToObj(ATask);
    if Assigned(jObj) then
    try
      jArr := TJSONArray(jObj.Find(cRECORDS));
      if assigned(jArr) then
      begin
        if Assigned(OnSuccessUpdateRecords) then
          OnSuccessUpdateRecords(ATask, jArr);
        for i := 0 to jArr.Count-1 do
        begin
          jEl := TJSONObject(jArr[i]);
          for n := 0 to jEl.Count-1 do
          begin
            if SameText(cSTAMP, jEl.Names[n]) then begin
              LastRecsStamp := jEl.Items[n].AsString;
              Break;
            end;
          end;
        end;
      end;
    finally
      jObj.Free;
    end;
  end else
    Disconnect;
end;

procedure TWCCURLClient.TaskFinished(ATask : THTTP2BackgroundTask);
begin
  FSynchroFinishedTasks.Push_back(ATask);
end;

procedure TWCCURLClient.SynchroFinishTasks;
var
  Tsk : THTTP2BackgroundTask;
begin
  while true do
  begin
    Tsk := FSynchroFinishedTasks.PopValue;
    if assigned(Tsk) then
    begin
      try
        if Length(Tsk.ErrorString) > 0 then
          AddLog(Tsk.ErrorString);

        case Tsk.ErrorCode of
        Integer( CURLE_OK) :
          if (not Tsk.IsSilent) or (Tsk.ResponseCode <> 200) then
            AddLog(Format('HTTP2 "%s". Code - %d', [Tsk.Path, Tsk.ResponseCode]));
        TASK_ERROR_ATTACH_REQ :
          AddLog(Format('Cant attach easy req to multi. Code - %d',
                              [Tsk.ErrorSubCode]));
        TASK_ERROR_CANT_EASY_CURL :
          AddLog(Format('Cant create easy req. Code - %d', [Tsk.ErrorSubCode]));
        else
          AddLog(Format('HTTP2 "%s" FAIL. Code - %d. Subcode - %d', [Tsk.Path,
                                              Tsk.ErrorCode, Tsk.ErrorSubCode]));
        end;

        if Length(Tsk.ErrorString) > 0 then
          AddLog(Tsk.ErrorString);

        if Assigned(Tsk.OnSuccess) then
          Tsk.OnSuccess(Tsk);

      finally
        Tsk.Free;
      end;
    end else
      Break;
  end;
end;

procedure TWCCURLClient.SynchroUpdateTasks;
var
  Tsk : THTTP2BackgroundTask;
begin
  while true do
  begin
    Tsk := FUpdates.PopValue;
    if assigned(Tsk) then
    begin
      Tsk.Lock;
      try
        if Assigned(OnSynchroUpdateTask) then
        begin
          OnSynchroUpdateTask(Tsk);
        end;
      finally
        Tsk.UnLock;
      end;
    end else
      Break;
  end;
end;

procedure TWCCURLClient.OnHasNextFrame(ATask : THTTP2BackgroundInStreamTask);
begin
  FUpdates.Push_back(ATask);
end;

procedure TWCCURLClient.SuccessIOStream(ATask : THTTP2BackgroundTask);
begin
  ATask.Lock;
  try
    if ATask is THTTP2BackgroundOutStreamTask then
      IsStreaming := false;
  finally
    ATask.UnLock;
  end;
  if assigned(OnSuccessIOStream) then
  begin
    OnSuccessIOStream(ATask);
  end;
end;

function TWCCURLClient.OnGetNextFrame(ATask : THTTP2BackgroundOutStreamTask
  ) : integer;
begin
  if Assigned(FFrame.Frame) then
  begin
    FFrame.Lock;
    try
      ATask.PushFrame(FFrame.ExtractFrame);
      Result := FFrame.FrameID;
    finally
      FFrame.UnLock;
    end;
    FUpdates.Push_back(ATask);
  end else
    Result := 0;
end;

function TWCCURLClient.ConsumeResponseToObj(ATask : THTTP2BackgroundTask
  ) : TJSONObject;
var jData : TJSONData;
    aResult : String;
    aCode, aRCode : Integer;
begin
  Result := nil;
  aCode := -1;
  aResult := cBAD;
  ATask.Response.Position := 0;
  try
    if ATask.Response.Size > 0 then
    begin
      try
        jData := GetJSON(ATask.Response);
        if (jData is TJSONObject) then
        begin
          Result := TJSONObject(jData);

          if Result.Find(cRESULT, jData) then
          begin
            aResult := jData.AsString;
            if SameText(aResult, cBAD) then
            begin
              if Result.Find(cCODE, jData) then
                aCode := jData.AsInteger;
              FreeAndNil(Result);
            end else
              aCode := 0;
          end else begin
            aResult := cBAD;
            FreeAndNil(Result);
          end;
        end else
          if assigned(jData) then FreeAndNil(jData);
      except
        Result := nil;
        aResult := cBAD;
      end;
    end;
  finally
    if (aCode > 0) or (not ATask.IsSilent) then
    begin
      if aCode < 0 then aRCode := 1 else
      if aCode > High(RESPONSE_ERRORS) then aRCode := 1 else
         aRCode := aCode;
      AddLog(Format('HTTP2 JSON Req result code [%d] - %s', [aCode, RESPONSE_ERRORS[aRCode]]));
    end;
  end;
end;

function TWCCURLClient.GetConnected : Boolean;
begin
  Lock;
  try
    Result := FConnected;
  finally
    UnLock;
  end;
end;

function TWCCURLClient.GetDevice : String;
begin
  Result := FSetts.Device;
end;

function TWCCURLClient.GetHost : String;
begin
  Result := FSetts.Host;
end;

function TWCCURLClient.GetNeedToUpdateDevices : Boolean;
begin
  Lock;
  try
    Result := FNeedToUpdateDevices;
  finally
    UnLock;
  end;
end;

function TWCCURLClient.GetNeedToUpdateMsgs : Boolean;
begin
  Lock;
  try
    Result := FNeedToUpdateMsgs;
  finally
    UnLock;
  end;
end;

function TWCCURLClient.GetNeedToUpdateRecords : Boolean;
begin
  Lock;
  try
    Result := FNeedToUpdateRecords;
  finally
    UnLock;
  end;
end;

function TWCCURLClient.GetNeedToUpdateStreams : Boolean;
begin
  Lock;
  try
    Result := FNeedToUpdateStreams;
  finally
    UnLock;
  end;
end;

function TWCCURLClient.GetProxy : String;
begin
  Result := FSetts.ProxyAddress;
end;

function TWCCURLClient.GetSID : String;
begin
  Result := FSetts.SID;
end;

function TWCCURLClient.GetStreaming : Boolean;
begin
  Lock;
  try
    Result := FStreaming;
  finally
    UnLock;
  end;
end;

function TWCCURLClient.GetVerifyTSL : Boolean;
begin
  Result := FSetts.VerifyTSL;
end;

procedure TWCCURLClient.SetNeedToUpdateDevices(AValue : Boolean);
begin
  Lock;
  try
    FNeedToUpdateDevices := AValue;
  finally
    UnLock;
  end;
end;

procedure TWCCURLClient.SetNeedToUpdateMsgs(AValue : Boolean);
begin
  Lock;
  try
    FNeedToUpdateMsgs := AValue;
  finally
    UnLock;
  end;
end;

procedure TWCCURLClient.SetNeedToUpdateRecords(AValue : Boolean);
begin
  Lock;
  try
    FNeedToUpdateRecords := AValue;
  finally
    UnLock;
  end;
end;

procedure TWCCURLClient.SetNeedToUpdateStreams(AValue : Boolean);
begin
  Lock;
  try
    FNeedToUpdateStreams := AValue;
  finally
    UnLock;
  end;
end;

procedure TWCCURLClient.SetProxy(const AValue : String);
begin
  FSetts.SetProxy(AValue);
end;

procedure TWCCURLClient.SetSID(const AValue : String);
begin
  FSetts.SID := AValue;
  if Assigned(OnSIDSetted) then
    OnSIDSetted(aValue);
end;

procedure TWCCURLClient.SetStreaming(AValue : Boolean);
begin
  Lock;
  try
    FStreaming := AValue;
  finally
    UnLock;
  end;
end;

procedure TWCCURLClient.SetVerifyTSL(AValue : Boolean);
begin
  FSetts.VerifyTSL := AValue;
end;

constructor TWCCURLClient.Create;
begin
  inherited Create;
  FInitialized := false;
  FLog := TThreadStringList.Create;
  FSynchroFinishedTasks := THTTP2BackgroundTasksProto.Create();
  FTaskPool := THTTP2AsyncBackground.Create;
  FUpdates := THTTP2StreamsTasks.Create;

  FFrame := THTTP2StreamFrame.Create;
  FStreaming := false;

  FSetts := THTTP2SettingsIntf.Create;

  TJSONData.CompressedJSON := true;
  curl_global_init(CURL_GLOBAL_ALL);
  FConnected := true;
  FNeedToUpdateRecords := false;
  FNeedToUpdateMsgs := false;
  FNeedToUpdateStreams := false;
  FNeedToUpdateDevices := false;
  Disconnect;
end;

procedure TWCCURLClient.Start;
begin
  FTaskPool.Start;
end;

procedure TWCCURLClient.TasksProceed;
begin
  SynchroUpdateTasks;
  SynchroFinishTasks;
end;

procedure TWCCURLClient.Proceed;
begin
  if Connected then
  begin
    if NeedToUpdateDevices then
      UpdateDevices;
    if NeedToUpdateRecords then
      UpdateRecords;
    if NeedToUpdateMsgs then
      UpdateMsgs;
    if NeedToUpdateStreams then
      UpdateStreams;
  end;
end;

destructor TWCCURLClient.Destroy;
begin
  FTaskPool.Terminate;
  FTaskPool.WaitFor;

  curl_global_cleanup();

  FSetts.Free;
  FSynchroFinishedTasks.Free;
  FTaskPool.Free;
  FFrame.Free;
  FUpdates.ExtractAll;
  FUpdates.Free;

  FLog.Free;

  inherited Destroy;
end;

procedure TWCCURLClient.Authorize(const aName, aPass : String);
var
  jObj : TJSONObject;
  aStr : String;
begin
  jObj := TJSONObject.Create([cNAME, aName,
                              cPASS, aPass,
                              cDEVICE, Device]);
  try
    if Length( Setts.MetaData ) > 0 then
    begin
      jObj.Add(cMETA, Setts.MetaData);
    end;
    aStr := jObj.AsJSON;
  finally
    jObj.Free;
  end;
  Disconnect;
  doPost('/authorize.json',  aStr, @SuccessAuth, false);
end;

function TWCCURLClient.LaunchOutStream(const aSubProto : String;
  aDelta : integer) : Boolean;
var
  Tsk : THTTP2BackgroundOutStreamTask;
begin
  Result := false;

  if DoInitMultiPipeling then
  begin
    Result := true;

    Tsk := THTTP2BackgroundOutStreamTask.Create(FTaskPool.Tasks, FSetts,
                                                aSubProto, aDelta, True);
    Tsk.OnFinish := @TaskFinished;
    Tsk.OnSuccess := @SuccessIOStream;

    if Assigned(OnAfterLaunchOutStream) then
      OnAfterLaunchOutStream(Tsk);

    Tsk.LaunchStream(@OnGetNextFrame);
    FTaskPool.AddTask(Tsk);
    IsStreaming := true;
  end;
end;

function TWCCURLClient.LaunchInStream(const aDeviceName : String) : Boolean;
var
  Tsk : THTTP2BackgroundInStreamTask;
begin
  Result := false;

  if DoInitMultiPipeling then
  begin
    Result := true;

    Tsk := THTTP2BackgroundInStreamTask.Create(FTaskPool.Tasks, FSetts,
                                                aDeviceName, True);
    Tsk.OnFinish := @TaskFinished;
    Tsk.OnSuccess := @SuccessIOStream;

    if Assigned(OnAfterLaunchInStream) then
      OnAfterLaunchInStream(Tsk);

    Tsk.LaunchStream(@OnHasNextFrame);
    FTaskPool.AddTask(Tsk);
  end;
end;

procedure TWCCURLClient.doPost(const aPath, aContent : String;
  OnSuccess : TOnHTTP2Finish; silent : Boolean);
var ptr : pointer;
begin
  if Length(aContent) > 0 then ptr := @(aContent[1]) else ptr := nil;
  doPost(aPath, ptr, Length(aContent), OnSuccess,
                          true, silent);
end;

procedure TWCCURLClient.doPost(const aPath : String; aContent : Pointer;
  aContentSize : Int64; OnSuccess : TOnHTTP2Finish; stack : boolean;
  silent : Boolean);
var
  Tsk : THTTP2BackgroundTask;
begin
  if DoInitMultiPipeling then
  begin
    Tsk := THTTP2BackgroundTask.Create(FTaskPool.Tasks, FSetts, silent);
    Tsk.OnFinish := @TaskFinished;
    Tsk.OnSuccess := OnSuccess;
    Tsk.doPost(aPath, aContent, aContentSize, stack);
    FTaskPool.AddTask(Tsk);
  end;
end;

procedure TWCCURLClient.AddLog(const STR : String);
begin
  FLog.Add('['+DateTimeToStr(Now)+'] '+Str);

  if Assigned(OnAddLog) then
    OnAddLog(Str);
end;

function TWCCURLClient.ExtractDeviceName(const dev : String) : String;
var
  jObj : TJSONData;
begin
  if Length(dev) > 0 then
  begin
    Result := dev;
    jObj := GetJSON(Result);
    if Assigned(jObj) then
    begin
      if jObj is TJSONObject then
        Result := TJSONObject(jObj).Get(cDEVICE, Result) else
        Result := jObj.AsString;
      jObj.Free;
    end;
  end else
    Result := Device;
end;

procedure TWCCURLClient.GetConfig;
var
  jObj : TJSONObject;
  aStr : String;
begin
  jObj := TJSONObject.Create([cSHASH, SID]);
  try
    aStr := jObj.AsJSON;
  finally
    jObj.Free;
  end;
   doPost('/getConfig.json',aStr, @SuccessGetConfig);
end;

procedure TWCCURLClient.SetConfig(const aStr : String);
begin
  doPost('/setConfig.json', aStr, nil);
end;

procedure TWCCURLClient.Disconnect;
begin
  FTaskPool.Tasks.Terminate;
  Lock;
  try
    FConnected := false;
    FNeedToUpdateDevices := false;
    FNeedToUpdateRecords := false;
    FNeedToUpdateMsgs    := false;
    FNeedToUpdateStreams := false;
  finally
    UnLock;
  end;

  SynchroFinishTasks;

  if Assigned(OnDisconnect) then
    OnDisconnect(Self);

  LastMsgsStamp := '{"msg":"sync"}';
  LastRecsStamp := '';
  SID := '';
end;

procedure TWCCURLClient.UpdateDevices;
var
  jObj : TJSONObject;
  aStr : String;
begin
  NeedToUpdateDevices := false;
  jObj := TJSONObject.Create([cSHASH, SID]);
  try
    aStr := jObj.AsJSON;
  finally
    jObj.Free;
  end;
  doPost('/getDevicesOnline.json',aStr, @SuccessUpdateDevices);
end;

procedure TWCCURLClient.UpdateRecords;
var
  jObj : TJSONObject;
  aStr : String;
begin
  NeedToUpdateRecords := false;
  jObj := TJSONObject.Create([cSHASH, SID,
                              cSTAMP, LastRecsStamp]);
  try
    aStr := jObj.AsJSON;
  finally
    jObj.Free;
  end;
  doPost('/getRecordCount.json', aStr, @SuccessUpdateRecords);
end;

procedure TWCCURLClient.UpdateMsgs;
var
  jObj : TJSONObject;
  aStr : String;
begin
  NeedToUpdateMsgs := false;
  jObj := TJSONObject.Create([cSHASH, SID,
                              cSTAMP, LastMsgsStamp]);
  try
    aStr := jObj.AsJSON;
  finally
    jObj.Free;
  end;
  doPost('/getMsgs.json',aStr,@SuccessUpdateMsgs)
end;

procedure TWCCURLClient.UpdateStreams;
var
  jObj : TJSONObject;
  aStr : String;
begin
  NeedToUpdateStreams := false;
  jObj := TJSONObject.Create([cSHASH, SID]);
  try
    aStr := jObj.AsJSON;
  finally
    jObj.Free;
  end;
  doPost('/getStreams.json',aStr,@SuccessUpdateStreams)
end;

procedure TWCCURLClient.DeleteRecords(aIndices : TJSONArray);
var aMsg : TJSONObject;
begin
  if assigned(aIndices) then
  begin
    aMsg := TJSONObject.Create([cSHASH,   SID,
                                cRECORDS, aIndices]);
    try
      doPost('/deleteRecords.json', aMsg.AsJSON, @SuccessDeleteRecords)
    finally
      aMsg.Free;
    end;
  end;
end;

procedure TWCCURLClient.SendMsg(aMsg : TJSONObject);
begin
  if assigned(aMsg) then begin
    aMsg.Add(cSHASH, SID);
    doPost('/addMsgs.json', aMsg.AsJSON, @SuccessSendMsg);
  end;
end;

procedure TWCCURLClient.RequestRecord(rid : integer);
var
  jObj : TJSONObject;
begin
  jobj := TJSONObject.Create([cSHASH, SID,
                              cRID, rid]);
  try
    doPost('/getRecordData.json', jObj.AsJSON, @SuccessRequestRecord);
  finally
    jObj.Free;
  end;
end;

procedure TWCCURLClient.SaveAsSnapshot(Buf : Pointer; Sz : Int64);
begin
  doPost('/addRecord.json?'+cSHASH+'='+HTTPEncode(SID), Buf, Sz, @SuccessSaveAsSnapshot, false);
end;

end.

