unit query_params;

interface

uses
  SysUtils, types, fs, logging;

// Функция для парсинга параметров запросов
function ParseQueryParams(const QueryTokens: TQueryTokenArray): TParamedQueryArray;

implementation

const
  PARAM_REGEX_START = '<@';
  PARAM_REGEX_END = '@>';
  PARAM_REGEX_SEPARATOR = ':';
  PARAM_ARRAY_PREFIX = 'array';

// Функция для парсинга параметров запросов
function ParseQueryParams(const QueryTokens: TQueryTokenArray): TParamedQueryArray;
var
  i, j, k, ik, to_ik, ParamCount, Position: Integer;
  Sql, ParamStr, Name, Type_, ElementType: string;
  ParamedQueries: TParamedQueryArray;
  ParamFound: Boolean;
  Log: TLogF;
  foundStart, foundEnd, founSep, prevEnd, secondSep: integer;
  activePart: string;
  isArrayParam: Boolean;
begin
  Log := GetLogger(LL_NO_LOGS);

  SetLength(ParamedQueries, Length(QueryTokens));
  
  for i := 0 to Length(QueryTokens) - 1 do
  begin
    ParamedQueries[i].QueryToken := QueryTokens[i];
    ParamedQueries[i].Params := nil;
    ParamedQueries[i].ResultSQL := QueryTokens[i].SQL;
    
    // Поиск и замена параметров
    Sql := QueryTokens[i].SQL;
    Position := 0;
    prevEnd := 1;
    log(LL_debug, sql);
    while prevEnd <> 0 do

    begin
      activePart := Copy(Sql, prevEnd, Length(Sql));
      foundStart := Pos(PARAM_REGEX_START, activePart);
      if foundStart = 0 then
        Break;
      
      foundEnd := Pos(PARAM_REGEX_END, activePart);
      if foundEnd = 0 then
        Break;

      ParamStr := Copy(activePart, foundStart + Length(PARAM_REGEX_START), foundEnd - foundStart - Length(PARAM_REGEX_START));
      
      // Извлечение имени и типа параметра
      founSep := Pos(PARAM_REGEX_SEPARATOR, ParamStr);
      if founSep > 0 then
      begin
        Name := Copy(ParamStr, 1, founSep - 1);
        Type_ := Copy(ParamStr, founSep + 1, Length(ParamStr) - founSep);
        isArrayParam := False;
        
        // Check if this is an array parameter
        if Pos(PARAM_ARRAY_PREFIX, Type_) = 1 then
        begin
          isArrayParam := True;
          secondSep := Pos(PARAM_REGEX_SEPARATOR, Type_);
          if secondSep > 0 then
          begin
            ElementType := Copy(Type_, secondSep + 1, Length(Type_) - secondSep);
            Type_ := Copy(Type_, 1, secondSep - 1); // Just 'array'
          end
          else
          begin
            raise Exception.Create(format('Error parsing array parameter: expected format ''name:array:type'', but got ''%s:%s''', [Name, Type_]));
          end;
        end;
        
        if not IsAllowedOwnType(Type_) then
          raise Exception.Create('Invalid own type. Got: ' + Type_);
        
        // For array parameters, update the SQL to have a placeholder for each value
        // We will do this at code generation time instead of here since we don't know
        // the array size yet. Just mark the parameter as an array for now.
        
        // Замена параметра на ? (за исключением массивов, для которых генерация плейсхолдеров происходит позже)
        ParamedQueries[i].ResultSQL := StringReplace(
          ParamedQueries[i].ResultSQL,
          PARAM_REGEX_START + ParamStr + PARAM_REGEX_END,
          '?',
          [rfReplaceAll]
        );
        
        // Добавление параметра
        ParamFound := False;

        for ik := 0 to Length(ParamedQueries[i].Params) - 1 do
        begin
          if ParamedQueries[i].Params[ik].Name = Name then
          begin
            ParamFound := True;
            SetLength(ParamedQueries[i].Params[ik].Positions, Length(ParamedQueries[i].Params[ik].Positions) + 1);
            ParamedQueries[i].Params[ik].Positions[Length(ParamedQueries[i].Params[ik].Positions) - 1] := Position;
          end;
        end;
        
        if not ParamFound then
        begin
          ParamCount := Length(ParamedQueries[i].Params);
          SetLength(ParamedQueries[i].Params, ParamCount + 1);
          ParamedQueries[i].Params[ParamCount].Name := Name;
          
          if isArrayParam then
          begin
            if ElementType = 'string' then
              ParamedQueries[i].Params[ParamCount].ParamType := otArrayString
            else if ElementType = 'int' then
              ParamedQueries[i].Params[ParamCount].ParamType := otArrayInteger;
            
            ParamedQueries[i].Params[ParamCount].IsArray := True;
          end
          else
          begin
            if Type_ = 'string' then
              ParamedQueries[i].Params[ParamCount].ParamType := otString
            else if Type_ = 'int' then
              ParamedQueries[i].Params[ParamCount].ParamType := otInteger;
            
            ParamedQueries[i].Params[ParamCount].IsArray := False;
          end;
          
          SetLength(ParamedQueries[i].Params[ParamCount].Positions, 1);
          ParamedQueries[i].Params[ParamCount].Positions[0] := Position;
        end;
        Inc(Position);
      end else begin
        raise Exception.Create(format('Error parsing params: expected in format ''name:type'', but got ''%s''', [ParamStr]));
      end;
      
      j := prevEnd + Pos(ParamStr, activePart) + Length(ParamStr) + Length(PARAM_REGEX_END);
      prevEnd := prevEnd + Pos(ParamStr, activePart) + Length(ParamStr) + Length(PARAM_REGEX_END);
      // log(LL_DEBUG, Stringifyint(prevEnd));
      // log(LL_DEBUG, Stringifyint(Length(sql)));
    end;
  end;
  
  Result := ParamedQueries;
end;

end.
