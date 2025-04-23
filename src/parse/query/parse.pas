unit query_parse;

interface

uses
  SysUtils, types, fs;

// Функция для парсинга запросов SQL
function ParseQueries(const SqlCodes: array of string): TQueryTokenArray;

implementation

const
  SQL_COMMENT_TOKEN = '--@';
  SQL_DELIMITER_TOKEN = ';';

// Функция для парсинга запросов SQL
function ParseQueries(const SqlCodes: array of string): TQueryTokenArray;
var
  Parts, SqlParts: array of string;
  i, j, k, QueryCount, TotalQueryCount: Integer;
  Line, Head, Sql, Name, Type_: string;
  QueryTokens: TQueryTokenArray;
begin
  SetLength(QueryTokens, 0);
  TotalQueryCount := 0;
  
  for i := 0 to Length(SqlCodes) - 1 do
  begin
    // Разделение SQL-кода на части
    SetLength(Parts, 0);
    SetLength(SqlParts, 0);
    
    // Разделение по комментариям
    Line := SqlCodes[i];
    j := 1;
    QueryCount := 0;
    
    while j <= Length(Line) do
    begin
      k := Pos(SQL_COMMENT_TOKEN, Copy(Line, j, Length(Line)));
      if k > 0 then
        k := k + j - 1
      else
        Break;
      
      j := k + Length(SQL_COMMENT_TOKEN);
      k := Pos(SQL_COMMENT_TOKEN, Copy(Line, j, Length(Line)));
      if k > 0 then
        k := k + j - 1
      else
        k := Length(Line) + 1;
      
      SetLength(Parts, QueryCount + 1);
      Parts[QueryCount] := Trim(Copy(Line, j, k - j));
      Inc(QueryCount);
      j := k;
    end;
    
    // Разделение по разделителям
    SetLength(SqlParts, QueryCount);
    for j := 0 to QueryCount - 1 do
    begin
      Line := Parts[j];
      k := Pos(SQL_DELIMITER_TOKEN, Line);
      if k > 0 then
        Line := Copy(Line, 1, k);
      
      SqlParts[j] := Trim(Line);
    end;
    
    // Проверка количества запросов
    if Length(Parts) <> Length(SqlParts) then
      raise Exception.Create('You can use only one query per method. Consider using `Subqueries` or `CTEs`');
    
    // Парсинг запросов
    SetLength(QueryTokens, TotalQueryCount + QueryCount);
    
    for j := 0 to QueryCount - 1 do
    begin
      Line := SqlParts[j];
      
      // Разделение на заголовок и SQL-код
      k := Pos(#10, Line);
      if k > 0 then
      begin
        Head := Copy(Line, 1, k - 1);
        Sql := Trim(Copy(Line, k + 1, Length(Line) - k));
      end
      else
      begin
        Head := Line;
        Sql := '';
      end;
      
      // Извлечение имени и типа запроса
      k := Pos(':', Head);
      if k > 0 then
      begin
        Name := Copy(Head, k + 1, Length(Head) - k);
        k := Pos(':', Name);
        if k > 0 then
        begin
          Type_ := Trim(Copy(Name, k + 1, Length(Name) - k));
          Name := Copy(Name, 1, k - 1);
          
          if not IsAllowedQueryReturnType(Type_) then begin
            raise Exception.Create('Invalid query return type. Got: ' + Type_);
          end;
          
          QueryTokens[TotalQueryCount].SQL := Sql;
          QueryTokens[TotalQueryCount].Name := Name;
          
          if Type_ = 'one' then
            QueryTokens[TotalQueryCount].ReturnType := qrtOne
          else if Type_ = 'many' then
            QueryTokens[TotalQueryCount].ReturnType := qrtMany
          else if Type_ = 'exec' then
            QueryTokens[TotalQueryCount].ReturnType := qrtExec;
          
          Inc(TotalQueryCount);
        end;
      end;
    end;
  end;
  
  // Обрезаем массив до фактического количества запросов
  SetLength(QueryTokens, TotalQueryCount);
  Result := QueryTokens;
end;

end.
