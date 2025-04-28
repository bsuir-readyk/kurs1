unit logging;

interface

uses
  SysUtils;

type TLOG_LEVEL = (LL_NO_LOGS, LL_DEBUG, LL_INFO, LL_WARN, LL_ERR);
type TLogF = procedure(level: TLOG_LEVEL; msg: string);

function TLOG_LEVEL_Stirngify(ll: TLOG_LEVEL): string;
procedure Log(level: TLOG_LEVEL; msg: string);

procedure LogLNo(level: TLOG_LEVEL; msg: string);
procedure LogLDebug(level: TLOG_LEVEL; msg: string);
procedure LogLInfo(level: TLOG_LEVEL; msg: string);
procedure LogLWarn(level: TLOG_LEVEL; msg: string);
procedure LogLErr(level: TLOG_LEVEL; msg: string);

function GetLogger(ll: TLOG_LEVEL): TLogF;

// function Stringify(v: any): string;
function StringifyArr(v: array of string): string;
function StringifyInt(v: integer): string;

implementation

// function Stringify(v: any): string;
// begin
//     result := Format('%v', [v]);
// end;
function StringifyArr(v: array of string): string;
var
    idx: Integer;
begin
    result := '';
    for idx := low(v) to High(v) do begin
        result := format('%s, %s', [result, v[idx]]);
    end;
end;
function StringifyInt(v: integer): string;
begin result := format('%d', [v]); end;


function TLOG_LEVEL_Stirngify(ll: TLOG_LEVEL): string;
begin
    case ll of
        LL_DEBUG: Result := 'DEBUG';
        LL_INFO: Result := 'INFO';
        LL_WARN: Result := 'WARN';
        LL_ERR: Result := 'ERROR';
    end;
end;

procedure Log(level: TLOG_LEVEL; msg: string);
begin
    writeln(Format('[%s]: %s', [TLOG_LEVEL_Stirngify(level), msg]));
end;

{ no closures? ok }
procedure LogLNo(level: TLOG_LEVEL; msg: string);
begin end;

procedure LogLDebug(level: TLOG_LEVEL; msg: string);
begin if (level >= LL_DEBUG) then begin Log(level, msg) end; end;

procedure LogLInfo(level: TLOG_LEVEL; msg: string);
begin if (level >= LL_INFO) then begin Log(level, msg) end; end;

procedure LogLWarn(level: TLOG_LEVEL; msg: string);
begin if (level >= LL_WARN) then begin Log(level, msg) end; end;

procedure LogLErr(level: TLOG_LEVEL; msg: string);
begin if (level >= LL_ERR) then begin Log(level, msg) end; end;

function GetLogger(ll: TLOG_LEVEL): TLogF;
begin
    case ll of
        LL_DEBUG: Result := @LogLDebug;
        LL_INFO: Result := @LogLInfo;
        LL_WARN: Result := @LogLWarn;
        LL_ERR: Result := @LogLErr;
        LL_NO_LOGS: Result := @LogLNo;
    end;
end;

end.
