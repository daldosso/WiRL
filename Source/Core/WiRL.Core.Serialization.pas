{******************************************************************************}
{                                                                              }
{       WiRL: RESTful Library for Delphi                                       }
{                                                                              }
{       Copyright (c) 2015-2017 WiRL Team                                      }
{                                                                              }
{       https://github.com/delphi-blocks/WiRL                                  }
{                                                                              }
{******************************************************************************}
unit WiRL.Core.Serialization;

interface

uses
  System.SysUtils, System.Classes, System.Rtti, System.SyncObjs,
  WiRL.Core.JSON, REST.Json;


type
  TWiRLJSONMapper = class
  public
    class function ValueToJSONValue(AValue: TValue): TJSONValue;
    class function ObjectToJSON(AObject: TObject): TJSONObject;
    class function ObjectToJSONString(AObject: TObject): string;

    class function JsonToObject<T: class, constructor>(AJsonObject: TJSOnObject): T; overload;
    class function JsonToObject(AType: TRttiType; AJsonObject: TJSOnObject): TObject; overload;

    class function JsonToObject<T: class, constructor>(const AJson: string): T; overload;
    class function JsonToObject(AType: TRttiType; const AJson: string): TObject; overload;

    class procedure JsonToObject(AObject: TObject; AJsonObject: TJsonObject); overload;
  end;

implementation

uses
  System.TypInfo,
  WiRL.Rtti.Utils,
  WiRL.Core.Utils;

{ TWiRLJSONMapper }

class function TWiRLJSONMapper.ValueToJSONValue(AValue: TValue): TJSONValue;
var
  LIndex: Integer;
begin
  case AValue.Kind of
    tkChar,
    tkString,
    tkWChar,
    tkLString,
    tkWString,
    tkVariant,
    tkUString:
    begin
      Result := TJSONString.Create(AValue.AsString);
    end;

    tkEnumeration:
    begin
      if AValue.TypeInfo = System.TypeInfo(Boolean) then
      begin
        if AValue.AsBoolean then
          Result := TJSONTrue.Create
        else
          Result := TJSONFalse.Create;
      end
      else
        Result := TJSONString.Create(GetEnumName(AValue.TypeInfo, AValue.AsOrdinal));
    end;

    tkInteger,
    tkInt64:
    begin
      Result := TJSONNumber.Create(AValue.AsInt64);
    end;

    tkFloat:
    begin
      if (AValue.TypeInfo = System.TypeInfo(TDateTime)) or
         (AValue.TypeInfo = System.TypeInfo(TDate)) or
         (AValue.TypeInfo = System.TypeInfo(TTime)) then
        Result := TJSONString.Create(TJSONHelper.DateToJSON(AValue.AsType<TDateTime>))
      else
        Result := TJSONNumber.Create(AValue.AsExtended);
    end;

    tkClass:
    begin
      Result := ObjectToJSON(AValue.AsObject);
    end;

    tkArray,
    tkDynArray:
    begin
      Result := TJSONArray.Create;
      for LIndex := 0 to AValue.GetArrayLength - 1 do
      begin
        (Result as TJSONArray).AddElement(
          ValueToJSONValue(AValue.GetArrayElement(LIndex))
        );
      end;
    end;

    tkSet:
    begin
      Result := TJSONString.Create(AValue.ToString);
    end;

    //tkRecord:

    {
    tkUnknown,
    tkMethod,
    tkPointer,
    tkProcedure,
    tkInterface,
    tkClassRef:
    }

    else
      Result := nil;
  end;
end;

class function TWiRLJSONMapper.ObjectToJSON(AObject: TObject): TJSONObject;
var
  LType: TRttiType;
  LProperty: TRttiProperty;
  LJSONValue: TJSONValue;
begin
  Result := TJSONObject.Create;
  try
    if Assigned(AObject) then
    begin
      LType := TRttiHelper.Context.GetType(AObject.ClassType);
      for LProperty in LType.GetProperties do
      begin
        if not LProperty.IsWritable then
          Continue;

        if LProperty.IsReadable and (LProperty.Visibility in [mvPublic, mvPublished]) then
        begin
          try
            LJSONValue := ValueToJSONValue(LProperty.GetValue(AObject));
          except
            raise Exception.CreateFmt(
              'Error converting property (%s) of type (%s)',
                [LProperty.Name, LProperty.PropertyType.Name]
            );
          end;
          if Assigned(LJSONValue) then
            Result.AddPair(LProperty.Name, LJSONValue);
        end;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

class function TWiRLJSONMapper.ObjectToJSONString(AObject: TObject): string;
var
  LObj: TJSONObject;
begin
  LObj := ObjectToJSON(AObject);
  try
    Result := TJSONHelper.ToJSON(LObj);
  finally
    LObj.Free;
  end;
end;

class function TWiRLJSONMapper.JsonToObject(AType: TRttiType; const AJson: string): TObject;
var
  LJObj: TJSONObject;
begin
  Result := TRttiHelper.CreateInstance(AType);
  LJObj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    TJson.JsonToObject(Result, LJObj);
  finally
    LJObj.Free;
  end;
end;

class function TWiRLJSONMapper.JsonToObject(AType: TRttiType; AJsonObject: TJSOnObject): TObject;
begin
  Result := TRttiHelper.CreateInstance(AType);
  TJson.JsonToObject(Result, AJsonObject);
end;

class procedure TWiRLJSONMapper.JsonToObject(AObject: TObject; AJsonObject: TJsonObject);
begin
  TJson.JsonToObject(AObject, AJsonObject);
end;

class function TWiRLJSONMapper.JsonToObject<T>(const AJson: string): T;
begin
  Result := TJson.JsonToObject<T>(AJson);
end;

class function TWiRLJSONMapper.JsonToObject<T>(AJsonObject: TJSOnObject): T;
begin
  Result := TJson.JsonToObject<T>(AJsonObject);
end;

end.
