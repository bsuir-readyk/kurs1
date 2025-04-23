unit query_params;

interface

uses
  SysUtils, types, fs;

// Функция для парсинга параметров запросов
function ParseQueryParams(const QueryTokens: TQueryTokenArray): TParamedQueryArray;

implementation

const
  PARAM_REGEX_START = '<@';
  PARAM_REGEX_END = '@>';
  PARAM_REGEX_SEPARATOR = ':';

// Функция для парсинга параметров запросов
function ParseQueryParams(const QueryTokens: TQueryTokenArray): TParamedQueryArray;
var
  i, j, k, ParamCount, Position: Integer;
  Sql, ParamStr, Name, Type_: string;
  ParamedQueries: TParamedQueryArray;
  ParamFound: Boolean;
begin
  SetLength(ParamedQueries, Length(QueryTokens));
  
  for i := 0 to Length(QueryTokens) - 1 do
  begin
    ParamedQueries[i].QueryToken := QueryTokens[i];
    ParamedQueries[i].Params := nil;
    ParamedQueries[i].ResultSQL := QueryTokens[i].SQL;
    
    // Поиск и замена параметров
    Sql := QueryTokens[i].SQL;
    Position := 0;
    
    j := 1;
    while j <= Length(Sql) do
    begin
      k := Pos(PARAM_REGEX_START, Copy(Sql, j, Length(Sql)));
      if k > 0 then
        k := k + j - 1;
      if k = 0 then
        Break;
      
      j := k + Length(PARAM_REGEX_START);
      k := Pos(PARAM_REGEX_END, Copy(Sql, j, Length(Sql)));
      if k > 0 then
        k := k + j - 1;
      if k = 0 then
        Break;
      
      ParamStr := Copy(Sql, j, k - j);
      
      // Замена параметра на ?
      ParamedQueries[i].ResultSQL := StringReplace(
        ParamedQueries[i].ResultSQL,
        PARAM_REGEX_START + ParamStr + PARAM_REGEX_END,
        '?',
        [rfReplaceAll]
      );
      
      // Извлечение имени и типа параметра
      k := Pos(PARAM_REGEX_SEPARATOR, ParamStr);
      if k > 0 then
      begin
        Name := Copy(ParamStr, 1, k - 1);
        Type_ := Copy(ParamStr, k + 1, Length(ParamStr) - k);
        
        if not IsAllowedOwnType(Type_) then
          raise Exception.Create('Invalid own type. Got: ' + Type_);
        
        // Добавление параметра
        ParamFound := False;
        for k := 0 to Length(ParamedQueries[i].Params) - 1 do
        begin
          if ParamedQueries[i].Params[k].Name = Name then
          begin
            ParamFound := True;
            SetLength(ParamedQueries[i].Params[k].Positions, Length(ParamedQueries[i].Params[k].Positions) + 1);
            ParamedQueries[i].Params[k].Positions[Length(ParamedQueries[i].Params[k].Positions) - 1] := Position;
            Break;
          end;
        end;
        
        if not ParamFound then
        begin
          ParamCount := Length(ParamedQueries[i].Params);
          SetLength(ParamedQueries[i].Params, ParamCount + 1);
          ParamedQueries[i].Params[ParamCount].Name := Name;
          
          if Type_ = 'string' then
            ParamedQueries[i].Params[ParamCount].ParamType := otString
          else if Type_ = 'int' then
            ParamedQueries[i].Params[ParamCount].ParamType := otInteger;
          
          SetLength(ParamedQueries[i].Params[ParamCount].Positions, 1);
          ParamedQueries[i].Params[ParamCount].Positions[0] := Position;
        end;
        
        Inc(Position);
      end;
      
      j := k + Length(PARAM_REGEX_END);
    end;
  end;
  
  Result := ParamedQueries;
end;

end.
