unit fs;

interface

uses
  SysUtils, types;

// Функции для работы с файлами
function GetConfig(const ConfigPath: string): TConfig;
function GetCodes(const Config: TConfig; const ConfigDir: string): TCodes;
procedure Write(const Content, FilePath: string);

// Вспомогательные функции для работы с файлами
function ReadFileToString(const FilePath: string): string;
procedure WriteStringToFile(const FilePath, Content: string);
type
  TStringArray = array of string;

function SplitString(const S, Delimiter: string): TStringArray;
function Trim(const S: string): string;

implementation

// Функция для удаления пробелов в начале и конце строки
function Trim(const S: string): string;
var
  I, L: Integer;
begin
  L := Length(S);
  I := 1;
  while (I <= L) and (S[I] <= ' ') do Inc(I);
  if I > L then Result := '' else
  begin
    while S[L] <= ' ' do Dec(L);
    Result := Copy(S, I, L - I + 1);
  end;
end;

// Функция для разделения строки на части по разделителю
function SplitString(const S, Delimiter: string): TStringArray;
var
  DelimPos, StartPos, Count: Integer;
  Temp: string;
begin
  Count := 0;
  Temp := S;
  
  // Подсчет количества разделителей
  StartPos := 1;
  repeat
    DelimPos := Pos(Delimiter, Copy(Temp, StartPos, Length(Temp)));
    if DelimPos > 0 then
    begin
      Inc(Count);
      StartPos := StartPos + DelimPos + Length(Delimiter) - 1;
    end;
  until DelimPos = 0;
  
  // Выделение памяти для результата
  SetLength(Result, Count + 1);
  
  // Разделение строки
  Count := 0;
  StartPos := 1;
  repeat
    DelimPos := Pos(Delimiter, Copy(Temp, StartPos, Length(Temp)));
    if DelimPos > 0 then
    begin
      Result[Count] := Copy(Temp, StartPos, DelimPos - 1);
      StartPos := StartPos + DelimPos + Length(Delimiter) - 1;
      Inc(Count);
    end
    else
    begin
      Result[Count] := Copy(Temp, StartPos, Length(Temp));
    end;
  until DelimPos = 0;
end;

// Функция для чтения файла в строку
function ReadFileToString(const FilePath: string): string;
var
  F: TextFile;
  Line, res: string;
begin
  res := '';
  AssignFile(F, FilePath);
  Reset(F);
  while not Eof(F) do
  begin
    ReadLn(F, Line);
    res := res + Line + #13#10;
  end;
  CloseFile(F);
  ReadFileToString := res;
end;

// Функция для записи строки в файл
procedure WriteStringToFile(const FilePath, Content: string);
var
  F: TextFile;
begin
  AssignFile(F, FilePath);
  Rewrite(F);
  WriteLn(F, Content);
  CloseFile(F);
end;

// Функция для чтения конфигурационного файла
function GetConfig(const ConfigPath: string): TConfig;
var
  ConfigContent, Lines: string;
  LineArray: array of string;
  Line, Key, Value: string;
  i, SepPos: Integer;
begin
  // Инициализация результата
  Result.Queries := nil;
  
  // Чтение файла
  ConfigContent := ReadFileToString(ConfigPath);
  
  // Разделение на строки
  LineArray := SplitString(ConfigContent, #13#10);
  
  // Парсинг каждой строки
  for i := 0 to Length(LineArray) - 1 do
  begin
    Line := LineArray[i];
    if Line = '' then Continue;
    
    SepPos := Pos(':', Line);
    if SepPos > 0 then
    begin
      Key := Trim(Copy(Line, 1, SepPos - 1));
      Value := Trim(Copy(Line, SepPos + 1, Length(Line) - SepPos));
      
      // Заполнение соответствующих полей конфигурации
      if Key = 'schema' then
        Result.Schema := Value
      else if Key = 'queries' then
      begin
        SetLength(Result.Queries, 1);
        Result.Queries[0] := Value;
      end
      else if Key = 'remove_trailing_s' then
        Result.RemoveTrailingS := LowerCase(Value) = 'true'
      else if Key = 'pakage.name' then
        Result.Package.Name := Value
      else if Key = 'pakage.path' then
        Result.Package.Path := Value;
    end;
  end;
end;

// Функция для чтения файлов схемы и запросов
function GetCodes(const Config: TConfig; const ConfigDir: string): TCodes;
var
  SchemaCodePath: string;
  QueryCodePaths: array of string;
  i: Integer;
begin
  // Формирование путей к файлам
  SchemaCodePath := IncludeTrailingPathDelimiter(ConfigDir) + Config.Schema;
  SetLength(QueryCodePaths, Length(Config.Queries));
  for i := 0 to Length(Config.Queries) - 1 do
    QueryCodePaths[i] := IncludeTrailingPathDelimiter(ConfigDir) + Config.Queries[i];
  
  // Чтение файлов
  Result.Schema := ReadFileToString(SchemaCodePath);
  
  SetLength(Result.Queries, Length(QueryCodePaths));
  for i := 0 to Length(QueryCodePaths) - 1 do
    Result.Queries[i] := ReadFileToString(QueryCodePaths[i]);
end;

// Функция для записи сгенерированных файлов
procedure Write(const Content, FilePath: string);
var
  Dir: string;
begin
  // Создание директории, если она не существует
  Dir := ExtractFileDir(FilePath);
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  
  // Запись файла
  WriteStringToFile(FilePath, Content);
end;

end.
