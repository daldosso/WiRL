{******************************************************************************}
{                                                                              }
{       WiRL: RESTful Library for Delphi                                       }
{                                                                              }
{       Copyright (c) 2015-2017 WiRL Team                                      }
{                                                                              }
{       https://github.com/delphi-blocks/WiRL                                  }
{                                                                              }
{******************************************************************************}
unit Server.Filters;

interface

uses
  WinApi.Windows, System.SysUtils, System.Classes,

  WiRL.Core.Registry,
  WiRL.http.Filters,
  WiRL.Core.Request,
  WiRL.Core.Response,
  WiRL.Core.Attributes,
  WiRL.Core.Exceptions,
  WiRL.Core.URL,
  WiRL.Core.Application,

  Server.Filters.Attributes, Server.Forms.Main;

type
  [PreMatching]
  TRequestLoggerFilter = class(TInterfacedObject, IWiRLContainerRequestFilter)
  private
    FMainForm: TMainForm;
  public
    procedure Filter(Request: TWiRLRequest);
    constructor Create(MainForm: TMainForm);
  end;

  [Priority(TWiRLPriorities.USER)] // Default priority
  TRequestCheckerFilter = class(TInterfacedObject, IWiRLContainerRequestFilter)
  private
    [Context] FApplication: TWiRLApplication;
  public
    procedure Filter(Request: TWiRLRequest);
  end;

  [PoweredByWiRL]
  TResponsePoweredByFilter = class(TInterfacedObject, IWiRLContainerResponseFilter)
  public
    procedure Filter(Request: TWiRLRequest; Response: TWiRLResponse);
  end;

  [ContentEncoding]
  TResponseEncodingFilter = class(TInterfacedObject, IWiRLContainerResponseFilter)
  private
    const ENC_GZIP = 'gzip';
    const ENC_DEFLATE = 'deflate';
    const ENC_IDENTITY = 'identity';
  public
    procedure Filter(Request: TWiRLRequest; Response: TWiRLResponse);
  end;


implementation

uses
  System.ZLib;

{ TRequestLoggerFilter }

procedure TRequestCheckerFilter.Filter(Request: TWiRLRequest);
begin
  if Pos('error', Request.Query) > 0 then
    raise EWiRLWebApplicationException.Create(Format('Filter error test [%s]', [FApplication.Name]), 400);
end;

{ TRequestLoggerFilter }

constructor TRequestLoggerFilter.Create(MainForm: TMainForm);
begin
  FMainForm := MainForm;
end;

procedure TRequestLoggerFilter.Filter(Request: TWiRLRequest);
var
  LMessage: string;
begin
  LMessage := DateTimeToStr(Now) + ' - ' + Request.Method + ' ' + Request.RawPathInfo;
  if Request.Query <> '' then
    LMessage := LMessage + '?' + Request.Query;
  FMainForm.Log(LMessage);
end;

{ TResponsePoweredByFilter }

procedure TResponsePoweredByFilter.Filter(Request: TWiRLRequest; Response: TWiRLResponse);
begin
  Response.HeaderFields['X-Powered-By'] := 'WiRL';
end;

{ TResponseEncodingFilter }

procedure TResponseEncodingFilter.Filter(Request: TWiRLRequest; Response: TWiRLResponse);
var
  LStrStream: TStringStream;
  LMemStream: TMemoryStream;

  procedure DoCompress(ASource, ADestination: TStream);
  var
    LCompressor: TZCompressionStream;
  begin
    ASource.Seek(0, TSeekOrigin.soBeginning);

    LCompressor := TZCompressionStream.Create(clDefault, ADestination);
    try
      LCompressor.CopyFrom(ASource, ASource.Size);
    finally
      LCompressor.Free;
    end;
  end;

begin
  if Request.AcceptableEncodings.Contains(ENC_DEFLATE) then
  begin
    if Assigned(Response.ContentStream) then
    begin
      LMemStream := TStringStream.Create;
      try
        DoCompress(Response.ContentStream, LMemStream);
        LMemStream.Position := soFromBeginning;
        Response.ContentStream.Free;
        Response.ContentStream := LMemStream;
      except
        LMemStream.Free;
      end;
      Response.ContentEncoding := ENC_DEFLATE;
    end
    else if Response.Content <> '' then
    begin
      LStrStream := TStringStream.Create(Response.Content);
      LStrStream.Position := soFromBeginning;
      try
        LMemStream := TMemoryStream.Create;
        try
          DoCompress(LStrStream, LMemStream);
          LMemStream.Position := soFromBeginning;
          Response.Content := '';
          Response.ContentStream := LMemStream;
        except
          FreeAndNil(LMemStream);
        end;
      finally
        LStrStream.Free;
      end;
      Response.ContentEncoding := ENC_DEFLATE;
    end;
  end;
end;

initialization
  TWiRLFilterRegistry.Instance.RegisterFilter<TRequestLoggerFilter>(
    function (): TObject
    begin
      Result := TRequestLoggerFilter.Create(MainForm);
    end
  );
  TWiRLFilterRegistry.Instance.RegisterFilter<TRequestCheckerFilter>;
  TWiRLFilterRegistry.Instance.RegisterFilter<TResponsePoweredByFilter>;
  TWiRLFilterRegistry.Instance.RegisterFilter<TResponseEncodingFilter>;

end.
