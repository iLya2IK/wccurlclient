unit WCCurlClientControls;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ValEdit,
  ComCtrls, StdCtrls, wccurlclient,
  JSONPropStorage;

type

  { TWCClientPropStorage }

  TWCClientPropStorage = class(TJSONPropStorage)
  private
    FDefaults : TStringList;
    function GetDefaults(aIndex : Integer) : String;
    function GetDevice : String;
    function GetHostName : String;
    function GetMetadata : String;
    function GetPassword : String;
    function GetProxy : String;
    function GetSID : String;
    function GetUserName : String;
    function GetProp(aPropName : Integer) : String;
    function GetVerifyTLS : Boolean;
    procedure SetDefaults(aIndex : Integer; AValue : String);
    procedure SetDevice(AValue : String);
    procedure SetHostName(AValue : String);
    procedure SetMetadata(AValue : String);
    procedure SetPassword(AValue : String);
    procedure SetProxy(AValue : String);
    procedure SetSID(AValue : String);
    procedure SetUserName(AValue : String);
    procedure SetProp(aPropName : Integer; const aValue : String);
    procedure SetVerifyTLS(AValue : Boolean);
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    property Defaults[aIndex : Integer] : String read GetDefaults write SetDefaults;

    const HOST_POS = 0;
    const PROXY_POS = 1;
    const USER_POS = 2;
    const PWRD_POS = 3;
    const DEVICE_POS = 4;
    const META_POS = 5;
    const SID_POS = 6;
    const MAX_PROPS = SID_POS;

    property HostName : String read GetHostName write SetHostName;
    property Proxy : String read GetProxy write SetProxy;
    property UserName : String read GetUserName write SetUserName;
    property Password : String read GetPassword write SetPassword;
    property Device : String read GetDevice write SetDevice;
    property Metadata : String read GetMetadata write SetMetadata;
    property SID : String read GetSID write SetSID;
    property VerifyTLS : Boolean read GetVerifyTLS write SetVerifyTLS;
  end;

  { TWCClientConfigEditor }

  TWCClientConfigEditor = class(TCustomControl)
  private
    FCURLClient : TWCCURLClient;
    FProps : TWCClientPropStorage;
    FValues : TValueListEditor;
    FVerifyTLS : TCheckBox;
    function GetDevice : String;
    function GetHostName : String;
    function GetMetadata : String;
    function GetPassword : String;
    function GetProxy : String;
    function GetSID : String;
    function GetUserName : String;
    function GetVerifyTLS : Boolean;
    procedure SetCURLClient(AValue : TWCCURLClient);
    procedure SetDevice(AValue : String);
    procedure SetHostName(AValue : String);
    procedure SetMetadata(AValue : String);
    procedure SetPassword(AValue : String);
    procedure SetProps(AValue : TWCClientPropStorage);
    procedure SetProxy(AValue : String);
    procedure SetSID(AValue : String);
    procedure SetUserName(AValue : String);

    procedure OptsEditingDone(Sender : TObject);
    procedure VerifyTSLCBChange(Sender : TObject);
    procedure SetVerifyTLS(AValue : Boolean);
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    procedure Apply;
    procedure RestoreProps;
    procedure SaveProps;

    property Props : TWCClientPropStorage read FProps write SetProps;
    property CURLClient : TWCCURLClient read FCURLClient write SetCURLClient;

    property HostName : String read GetHostName write SetHostName;
    property Proxy : String read GetProxy write SetProxy;
    property UserName : String read GetUserName write SetUserName;
    property Password : String read GetPassword write SetPassword;
    property Device : String read GetDevice write SetDevice;
    property Metadata : String read GetMetadata write SetMetadata;
    property SID : String read GetSID write SetSID;
    property VerifyTLS : Boolean read GetVerifyTLS write SetVerifyTLS;
  end;

resourcestring
  rsServer    = 'Server';
  rsProxy     = 'Proxy';
  rsUser      = 'User name';
  rsPwrd      = 'Password';
  rsDevice    = 'Device';
  rsMeta      = 'Metadata';
  rsSID       = 'Session ID';
  rsVerifyTLS = 'Verify TLS';

implementation

const
  csServer    = 'Server';
  csProxy     = 'Proxy';
  csUser      = 'User';
  csPwrd      = 'Password';
  csDevice    = 'Device';
  csMeta      = 'Metadata';
  csSID       = 'SID';
  csVerifyTLS = 'VerifyTLS';

  PROPS_STR : Array [0..6] of String = (csServer, csProxy, csUser, csPwrd,
                                        csDevice, csMeta, csSID);

{ TWCClientConfigEditor }

procedure TWCClientConfigEditor.SetCURLClient(AValue : TWCCURLClient);
begin
  if FCURLClient = AValue then Exit;
  FCURLClient := AValue;
  Apply;
end;

function TWCClientConfigEditor.GetDevice : String;
begin
  Result := FValues.Cells[1, TWCClientPropStorage.DEVICE_POS];
end;

function TWCClientConfigEditor.GetHostName : String;
begin
  Result := FValues.Cells[1, TWCClientPropStorage.HOST_POS];
end;

function TWCClientConfigEditor.GetMetadata : String;
begin
  Result := FValues.Cells[1, TWCClientPropStorage.META_POS];
end;

function TWCClientConfigEditor.GetPassword : String;
begin
  Result := FValues.Cells[1, TWCClientPropStorage.PWRD_POS];
end;

function TWCClientConfigEditor.GetProxy : String;
begin
  Result := FValues.Cells[1, TWCClientPropStorage.PROXY_POS];
end;

function TWCClientConfigEditor.GetSID : String;
begin
  Result := FValues.Cells[1, TWCClientPropStorage.SID_POS];
end;

function TWCClientConfigEditor.GetUserName : String;
begin
  Result := FValues.Cells[1, TWCClientPropStorage.USER_POS];
end;

function TWCClientConfigEditor.GetVerifyTLS : Boolean;
begin
  Result := FVerifyTLS.Checked;
end;

procedure TWCClientConfigEditor.SetDevice(AValue : String);
begin
  FValues.Cells[1, TWCClientPropStorage.DEVICE_POS] := AValue;
end;

procedure TWCClientConfigEditor.SetHostName(AValue : String);
begin
  FValues.Cells[1, TWCClientPropStorage.HOST_POS] := AValue;
end;

procedure TWCClientConfigEditor.SetMetadata(AValue : String);
begin
  FValues.Cells[1, TWCClientPropStorage.META_POS] := AValue;
end;

procedure TWCClientConfigEditor.SetPassword(AValue : String);
begin
  FValues.Cells[1, TWCClientPropStorage.PWRD_POS] := AValue;
end;

procedure TWCClientConfigEditor.SetProxy(AValue : String);
begin
  FValues.Cells[1, TWCClientPropStorage.PROXY_POS] := AValue;
end;

procedure TWCClientConfigEditor.SetSID(AValue : String);
begin
  FValues.Cells[1, TWCClientPropStorage.SID_POS] := AValue;
end;

procedure TWCClientConfigEditor.SetUserName(AValue : String);
begin
  FValues.Cells[1, TWCClientPropStorage.USER_POS] := AValue;
end;

procedure TWCClientConfigEditor.SetProps(AValue : TWCClientPropStorage);
begin
  if FProps = AValue then Exit;
  FProps := AValue;
  RestoreProps;
end;

procedure TWCClientConfigEditor.OptsEditingDone(Sender : TObject);
begin
  Apply;
end;

procedure TWCClientConfigEditor.VerifyTSLCBChange(Sender : TObject);
begin
  if Assigned(FCURLClient) then
    FCURLClient.VerifyTSL := FVerifyTLS.Checked;
end;

procedure TWCClientConfigEditor.SetVerifyTLS(AValue : Boolean);
begin
  FVerifyTLS.Checked := AValue;
end;

constructor TWCClientConfigEditor.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FCURLClient := nil;
  FValues := TValueListEditor.Create(Self);
  FValues.Parent := Self;
  FValues.Strings.AddPair(rsServer, '');
  FValues.Strings.AddPair(rsProxy, '');
  FValues.Strings.AddPair(rsUser, '');
  FValues.Strings.AddPair(csPwrd, '');
  FValues.Strings.AddPair(csDevice, '');
  FValues.Strings.AddPair(csMeta, '');
  FValues.Strings.AddPair(csSID, '');
  FValues.DisplayOptions := [doAutoColResize, doKeyColFixed];
  FValues.OnEditingDone := @OptsEditingDone;
  FValues.Align := alClient;

  FVerifyTLS := TCheckBox.Create(Self);
  FVerifyTLS.Parent := Self;
  FVerifyTLS.Caption := rsVerifyTLS;
  FVerifyTLS.Top := 100;
  FVerifyTLS.OnChange := @VerifyTSLCBChange;
  FVerifyTLS.Align := alBottom;
end;

destructor TWCClientConfigEditor.Destroy;
begin
  inherited Destroy;
end;

procedure TWCClientConfigEditor.Apply;
begin
  if Assigned(FCURLClient) then
  with FCURLClient do
  begin
    Setts.Device   := GetDevice;
    Setts.SetProxy(GetProxy);
    Setts.MetaData := GetMetadata;
    Setts.Host     := GetHostName;
    Setts.SID      := GetSID;
  end;
end;

procedure TWCClientConfigEditor.RestoreProps;
var
  i : integer;
begin
  if Assigned(FProps) then
  begin
    for i := 0 to FProps.MAX_PROPS-1 do
      FValues.Cells[1, i] := FProps.GetProp(i);

    VerifyTLS := FProps.VerifyTLS;
  end;
end;

procedure TWCClientConfigEditor.SaveProps;
var
  i : integer;
begin
  if Assigned(FProps) then
  begin
    for i := 0 to FProps.MAX_PROPS do
      FProps.SetProp(i, FValues.Cells[1, i]);

    FProps.VerifyTLS := VerifyTLS;
  end;
end;

{ TWCClientPropStorage }

function TWCClientPropStorage.GetDefaults(aIndex : Integer) : String;
begin
  if (aIndex >= 0) and (aIndex <= MAX_PROPS) then
    Result := FDefaults[aIndex] else
    Result := '';
end;

function TWCClientPropStorage.GetDevice : String;
begin
  Result := GetProp(DEVICE_POS);
end;

function TWCClientPropStorage.GetHostName : String;
begin
  Result := GetProp(HOST_POS);
end;

function TWCClientPropStorage.GetMetadata : String;
begin
  Result := GetProp(META_POS);
end;

function TWCClientPropStorage.GetPassword : String;
begin
  Result := GetProp(PWRD_POS);
end;

function TWCClientPropStorage.GetProxy : String;
begin
  Result := GetProp(PROXY_POS);
end;

function TWCClientPropStorage.GetSID : String;
begin
  Result := GetProp(SID_POS);
end;

function TWCClientPropStorage.GetUserName : String;
begin
  Result := GetProp(USER_POS);
end;

function TWCClientPropStorage.GetProp(aPropName : Integer) : String;
begin
  Result := ReadString(PROPS_STR[aPropName], FDefaults[aPropName]);
end;

function TWCClientPropStorage.GetVerifyTLS : Boolean;
begin
  Result := ReadBoolean(csVerifyTLS, true);
end;

procedure TWCClientPropStorage.SetDefaults(aIndex : Integer; AValue : String);
begin
  FDefaults[aIndex] := AValue;
end;

procedure TWCClientPropStorage.SetDevice(AValue : String);
begin
  SetProp(DEVICE_POS, AValue);
end;

procedure TWCClientPropStorage.SetHostName(AValue : String);
begin
  SetProp(HOST_POS, AValue);
end;

procedure TWCClientPropStorage.SetMetadata(AValue : String);
begin
  SetProp(META_POS, AValue);
end;

procedure TWCClientPropStorage.SetPassword(AValue : String);
begin
  SetProp(PWRD_POS, AValue);
end;

procedure TWCClientPropStorage.SetProxy(AValue : String);
begin
  SetProp(PROXY_POS, AValue);
end;

procedure TWCClientPropStorage.SetSID(AValue : String);
begin
  SetProp(SID_POS, AValue);
end;

procedure TWCClientPropStorage.SetUserName(AValue : String);
begin
  SetProp(USER_POS, AValue);
end;

procedure TWCClientPropStorage.SetProp(aPropName : Integer;
  const aValue : String);
begin
  WriteString(PROPS_STR[aPropName], aValue);
end;

procedure TWCClientPropStorage.SetVerifyTLS(AValue : Boolean);
begin
  WriteBoolean(csVerifyTLS, AValue);
end;

constructor TWCClientPropStorage.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FDefaults := TStringList.Create;
  FDefaults.Add('https://localhost:443');
  FDefaults.Add('');
  FDefaults.Add('');
  FDefaults.Add('');
  FDefaults.Add('user-device');
  FDefaults.Add('');
  FDefaults.Add('');
end;

destructor TWCClientPropStorage.Destroy;
begin
  FDefaults.Free;
  inherited Destroy;
end;

end.

