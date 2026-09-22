{ SelfTest: one program that uses every part of MIDletPascal the compiler
  accepts. Every type, every statement form, every extension of the 3.5 port
  and every runtime helper class (FS, S, F or Real, RS, H, P, SM).

  Compiled, it is the widest single input the compiler gets, which is what
  makes it the file to diff between two builds of the compiler. Run on a
  phone or an emulator, it computes results it knows the answers to, counts
  the ones that came out wrong and draws the tally; keys 1 to 5 then open the
  parts that need a screen, a network or a phone, and 0 quits. }

(* the four comment styles are all used on purpose: this one is standard *)
// this one is a c++ line comment, an extension of the port
/* and this is a c block comment, another extension */

program SelfTest;

const
  ANSWER = 42;
  NEG = -42;                    // a negative constant: new in 3.5
  MASK = $FF;                   // hex literal
  LOW = -2147483647;
  GREETING = 'hello';
  QUOTED = 'it''s';             // a doubled quote inside a string
  CSTYLE = "double quoted";     // c-style string literal: new in 3.5
  LETTER_A = #65;               // a character by decimal code
  LETTER_B = #$42;              // a character by hex code
  RATIO = 0.25;
  YES = true;
  STORE = 'selftest';
  MAX_FAILS = 8;

type
  TIndex = integer;             // a plain alias
  TPoint = record
    x, y: integer;
  end;
  TPlayer = record
    name: string;
    score: integer;
    alive: boolean;
    ratio: real;
    grade: char;
  end;
  TGrid = array[0..2, 0..3] of integer;
  TNames = array[1..3] of string;

var
  passed, failed: integer;
  failNames: array[1..MAX_FAILS] of string;
  grid: TGrid;
  names: TNames;
  reals: array[1..4] of real;
  offsets: array[5..9] of integer;   // a lower bound other than 0 or 1
  players: array[0..1] of TPlayer;
  origin: TPoint;
  tile: image;
  key: integer;

{ ---------------------------------------------------------------- helpers }

procedure Check(name: string; ok: boolean);
begin
  if ok then
    passed := passed + 1
  else
  begin
    failed := failed + 1;
    if failed <= MAX_FAILS then
      failNames[failed] := name;
  end;
end;

// fixed point (-m1) has 12 fractional bits, so compare with a tolerance
function Near(a, b: real): boolean;
begin
  Near := Rabs(a - b) < 0.05;
end;

procedure Cls;
begin
  SetColor(0, 0, 0);
  FillRect(0, 0, GetWidth, GetHeight);
  SetColor(255, 255, 255);
end;

{ ------------------------------------------------------------- integers }

procedure TestIntegers;
var
  a, b: integer;
  i: TIndex;
begin
  a := 7;
  b := 2;
  Check('div', a div b = 3);
  Check('mod', a mod b = 1);
  Check('slash on integers', a / b = 3);
  Check('negative div', -7 div 2 = -3);
  Check('negative mod', -7 mod 2 = -1);
  Check('shl', 1 shl 10 = 1024);
  Check('shr keeps the sign', -16 shr 2 = -4);
  Check('ushr drops the sign', -16 ushr 28 = 15);
  Check('<<', 1 << 3 = 8);
  Check('>>', 256 >> 4 = 16);
  Check('>>>', -1 >>> 31 = 1);
  Check('hex literal', MASK = 255);
  Check('negative constant', NEG + ANSWER = 0);
  Check('wraparound', LOW - 2 = 2147483647);
  Check('abs', Abs(NEG) = 42);
  Check('sqr', Sqr(12) = 144);
  Check('odd', Odd(7) and not Odd(8));
  Check('precedence', 2 + 3 * 4 = 14);
  Check('unary minus', -a * b = -14);
  Check('random range', Random(1) = 0);
  i := ANSWER;
  Check('alias type', i = 42);
end;

{ -------------------------------------------------------------- strings }

procedure TestStrings;
var
  s: string;
  c: char;
  i: integer;
begin
  Check('length', Length(GREETING) = 5);
  Check('empty string', Length('') = 0);
  Check('doubled quote', Length(QUOTED) = 4);
  Check('double-quoted literal', CSTYLE = 'double quoted');
  Check('concat', GREETING + ' world' = 'hello world');
  Check('concat integer', 'n=' + 5 = 'n=5');
  Check('concat boolean', 'b=' + YES = 'b=true');
  Check('concat chars', 'x' + 'y' = 'xy');
  Check('copy', Copy('MIDletPascal', 2, 5) = 'Dle');
  Check('pos', Pos('hello world', 'world') = 6);
  Check('pos missing', Pos('abc', 'z') = -1);
  Check('upcase', Upcase('abc') = 'ABC');
  Check('locase', Locase('ABC') = 'abc');
  Check('getchar', GetChar('abc', 1) = 'b');
  Check('setchar', SetChar('abc', 'X', 1) = 'aXc');
  Check('integer to string', IntegerToString(-12) = '-12');
  Check('string to integer', StringToInteger('42') = 42);
  Check('string to negative', StringToInteger('-7') = -7);
  Check('string to integer bad', StringToInteger('x') = 0);
  Check('string compare', ('abc' = 'abc') and ('abc' <> 'ABC'));
  c := LETTER_A;
  Check('char by code', c = 'A');
  Check('char by hex code', LETTER_B = 'B');
  Check('ord', Ord('A') = 65);
  Check('chr', Chr(66) = 'B');
  Check('char compare', 'a' < 'b');
  s := '';
  for i := 1 to 3 do
    s := s + i;
  Check('string built in a loop', s = '123');
end;

{ ------------------------------------------------------------- booleans }

procedure TestBooleans;
var
  p, q: boolean;
begin
  p := true;
  q := false;
  Check('and not', p and not q);
  Check('or', q or p);
  Check('xor same', (p xor p) = false);
  Check('xor mixed', p xor q);
  Check('not binds tightest', not q and p);
  Check('relational', (1 < 2) and (2 <= 2) and (3 > 2) and (3 >= 3) and (1 <> 2));
end;

{ ---------------------------------------------------------------- reals }

procedure TestReals;
var
  r: real;
begin
  r := 2.5;
  Check('trunc', Trunc(r) = 2);
  Check('frac', Near(Frac(1.25), 0.25));
  Check('real constant', Near(RATIO * 4, 1.0));
  Check('integer to real', Near(7 / 2.0, 3.5));
  Check('real compare', (r > 2) and (r < 3));
  Check('sqrt', Near(Sqrt(16), 4));
  Check('pow', Near(Pow(2, 10), 1024));
  Check('sin cos', Near(Sin(0), 0) and Near(Cos(0), 1));
  Check('tan', Near(Tan(0), 0));
  Check('degrees', Near(ToDegrees(pi), 180));
  Check('radians', Near(ToRadians(180), pi));
  Check('atan2', Near(Atan2(1, 1), pi / 4));
  Check('asin acos atan', Near(Asin(0), 0) and Near(Acos(1), 0) and Near(Atan(0), 0));
  Check('exp log', Near(Log(Exp(1)), 1));
  Check('log10', Near(Log10(100), 2));
  Check('rabs', Near(Rabs(-1.5), 1.5));
  Check('string to real', Near(StringToReal('2.5', 10), 2.5));
  reals[1] := 1.5;
  reals[2] := reals[1] * 2;
  Check('real array', Near(reals[2], 3));
end;

{ ------------------------------------------------------ arrays, records }

procedure TestArrays;
var
  i, j, sum: integer;
begin
  for i := 0 to 2 do
    for j := 0 to 3 do
      grid[i, j] := i * 10 + j;
  Check('2d array', grid[2, 3] = 23);
  sum := 0;
  for i := 0 to 2 do
    sum := sum + grid[i, 0];
  Check('2d column', sum = 30);
  for i := 5 to 9 do
    offsets[i] := i * i;
  Check('shifted bounds', (offsets[5] = 25) and (offsets[9] = 81));
  names[1] := 'ann';
  names[2] := 'bob';
  names[3] := names[1] + names[2];
  Check('string array', names[3] = 'annbob');
  sum := 0;
  for i := 3 downto 1 do
    sum := sum + Length(names[i]);
  Check('downto', sum = 12);
end;

procedure TestRecords;
begin
  origin.x := 3;
  origin.y := 4;
  Check('record fields', origin.x * origin.y = 12);
  players[0].name := 'ann';
  players[0].score := 10;
  players[0].alive := true;
  players[0].ratio := 0.5;
  players[0].grade := 'A';
  players[1].name := 'bob';
  players[1].score := players[0].score * 2;
  players[1].alive := not players[0].alive;
  players[1].ratio := players[0].ratio * 3;
  players[1].grade := 'B';
  Check('record array', players[1].score = 20);
  Check('record string', players[0].name + players[1].name = 'annbob');
  Check('record boolean', players[0].alive and not players[1].alive);
  Check('record real', Near(players[1].ratio, 1.5));
  Check('record char', players[1].grade > players[0].grade);
end;

{ --------------------------------------------------------- control flow }

function IsOdd(n: integer): boolean; forward;

function IsEven(n: integer): boolean;
begin
  if n = 0 then
    IsEven := true
  else
    IsEven := IsOdd(n - 1);
end;

function IsOdd(n: integer): boolean;
begin
  if n = 0 then
    IsOdd := false
  else
    IsOdd := IsEven(n - 1);
end;

function Factorial(n: integer): integer;
begin
  if n <= 1 then
    Factorial := 1
  else
    Factorial := n * Factorial(n - 1);
end;

// the result keyword and an early exit, both extensions of the port
function FirstNegative(a, b, c: integer): integer;
begin
  result := 0;
  if a < 0 then
  begin
    result := a;
    exit;
  end;
  if b < 0 then
  begin
    result := b;
    exit;
  end;
  if c < 0 then
    result := c;
end;

procedure TestControlFlow;
var
  i, j, n: integer;
begin
  n := 0;
  for i := 1 to 10 do
    n := n + i;
  Check('for', n = 55);
  n := 0;
  i := 10;
  while i > 0 do
  begin
    n := n + 1;
    i := i - 3;
  end;
  Check('while', n = 4);
  n := 0;
  repeat
    n := n + 1;
  until n >= 5;
  Check('repeat', n = 5);
  n := 0;
  repeat
    n := n + 1;
    if n = 7 then
      break;
  forever;
  Check('forever with break', n = 7);
  n := 0;
  for i := 1 to 3 do
    for j := 1 to 3 do
    begin
      if j = 2 then
        break;                   // leaves the inner loop only
      n := n + 1;
    end;
  Check('break is per loop', n = 3);
  n := 0;
  if n = 1 then
    n := 10
  else if n = 0 then
    n := 20
  else
    n := 30;
  Check('else if chain', n = 20);
  Check('recursion', Factorial(6) = 720);
  Check('mutual recursion', IsEven(10) and IsOdd(7));
  Check('result and exit', (FirstNegative(1, -2, -3) = -2) and (FirstNegative(1, 2, 3) = 0));
end;

{ ---------------------------------------------------------- extensions }

// raw jvm bytecode: the block below adds two constants and drops the
// result, and the label test branches over a nop
procedure TestBytecode;
begin
  bytecode
    iconst_1;
    iconst_2;
    iadd;
    pop;
  end;
  bytecode
    iconst_0;
    ifeq :1;
    nop;
    :1;
  end;
  inline(nop;);                  // the deprecated spelling, warns W464
  Assert(true);
  Debug('bytecode blocks executed');
  Check('bytecode block', true);
end;

{ ------------------------------------------------------ record store (RS) }

procedure TestRecordStore;
var
  rs: recordStore;
  id, other: integer;
begin
  DeleteRecordStore(STORE);
  rs := OpenRecordStore(STORE);
  id := AddRecordStoreEntry(rs, 'first');
  Check('rs add', id >= 1);
  Check('rs read', ReadRecordStoreEntry(rs, id) = 'first');
  Check('rs size', GetRecordStoreSize(rs) = 1);
  ModifyRecordStoreEntry(rs, 'changed', id);
  Check('rs modify', ReadRecordStoreEntry(rs, id) = 'changed');
  other := AddRecordStoreEntry(rs, 'second');
  Check('rs next id', GetRecordStoreNextId(rs) = other + 1);
  DeleteRecordStoreEntry(rs, id);
  Check('rs delete entry', GetRecordStoreSize(rs) = 1);
  CloseRecordStore(rs);
  DeleteRecordStore(STORE);
end;

{ ----------------------------------------------------- resources, images }

procedure TestResources;
var
  res: resource;
  half: image;
begin
  res := OpenResource('/lines.txt');
  Check('resource line', ReadLine(res) = 'first line');
  Check('resource byte', ReadByte(res) = Ord('s'));
  Check('resource available', ResourceAvailable(res));
  CloseResource(res);
  tile := LoadImage('/tile.png');
  Check('image size', (GetImageWidth(tile) = 8) and (GetImageHeight(tile) = 8));
  half := ImageFromImage(tile, 0, 0, 4, 8);
  Check('image from image', GetImageWidth(half) = 4);
  half := ImageFromCanvas(0, 0, 10, 10);
  Check('image from canvas', GetImageHeight(half) = 10);
end;

{ ------------------------------------------------------------ date, time }

procedure TestTime;
var
  t, started: integer;
begin
  t := GetCurrentTime;
  Check('year', GetYear(t) >= 2026);
  Check('month', (GetMonth(t) >= 1) and (GetMonth(t) <= 12));
  Check('day', (GetDay(t) >= 1) and (GetDay(t) <= 31));
  Check('hour', (GetHour(t) >= 0) and (GetHour(t) < 24));
  Check('minute', (GetMinute(t) >= 0) and (GetMinute(t) < 60));
  Check('second', (GetSecond(t) >= 0) and (GetSecond(t) < 60));
  Check('week day', (GetWeekDay(t) >= 1) and (GetWeekDay(t) <= 7));
  Check('year day', (GetYearDay(t) >= 1) and (GetYearDay(t) <= 366));
  started := GetRelativeTimeMs;
  Delay(20);
  Check('delay', GetRelativeTimeMs - started >= 20);
  Check('property', Length(GetProperty('microedition.configuration')) > 0);
  Check('not paused', not IsMidletPaused);
end;

{ ---------------------------------------------------------- drawing (5) }

procedure DrawingDemo;
var
  w, h, x: integer;
begin
  w := GetWidth;
  h := GetHeight;
  repeat
    Cls;
    SetColor(200, 40, 40);
    Check('color red', GetColorRed = 200);
    Check('color green', GetColorGreen = 40);
    Check('color blue', GetColorBlue = 40);
    DrawLine(0, 0, w, h);
    DrawRect(4, 4, w div 3, h div 3);
    FillRect(8, 8, w div 4, h div 4);
    SetColor(40, 200, 40);
    DrawRoundRect(w div 2, 4, w div 3, h div 3, 8, 8);
    FillRoundRect(w div 2 + 4, 8, w div 4, h div 4, 8, 8);
    SetColor(40, 40, 200);
    DrawEllipse(4, h div 2, w div 3, h div 3);
    FillEllipse(8, h div 2 + 4, w div 4, h div 4);
    DrawArc(w div 2, h div 2, w div 3, h div 3, 0, 270);
    for x := 0 to 20 do
      Plot(w div 2 + x * 2, h - 8);
    DrawImage(tile, w - 12, h - 12);
    SetClip(0, 0, w, h div 2);
    SetColor(255, 255, 255);
    SetFont(FONT_FACE_PROPORTIONAL, FONT_STYLE_BOLD, FONT_SIZE_LARGE);
    DrawText('bold', 0, h div 2 - GetStringHeight('bold'));
    SetDefaultFont;
    DrawText('color: ' + IsColorDisplay + ' ' + GetColorsNum, 0, h - GetStringHeight('x') * 2);
    SetClip(0, 0, w, h);
    DrawText('any key to go back', (w - GetStringWidth('any key to go back')) div 2, 0);
    Repaint;
    Delay(50);
    key := GetKeyPressed;
  until key <> KE_NONE;
  Check('key to action', KeyToAction(KE_KEY5) = GA_FIRE);
end;

{ ------------------------------------------------------------ forms (1) }

procedure FormsDemo;
var
  ok, back, done, closed: command;
  cmd: command;
  note, nameField, gauge, choice, dateField, item: integer;
  s: string;
begin
  ShowForm;
  SetFormTitle('Forms');
  SetTicker('MIDletPascal self-test');
  note := FormAddString('Fill in the form, then press OK');
  nameField := FormAddTextField('Name', 'Pascal', 32, TF_ANY);
  gauge := FormAddGauge('Level', true, 10, 3);
  choice := FormAddChoice('Mode', CH_EXCLUSIVE);
  item := ChoiceAppendString(choice, 'canvas');   // a function: its result has to go somewhere
  item := ChoiceAppendStringImage(choice, 'form', tile);
  dateField := FormAddDateField('When', DF_DATE_TIME);
  FormSetDate(dateField, GetCurrentTime);
  item := FormAddSpace;
  item := FormAddImage(tile);
  ok := CreateCommand('OK', CM_OK, 1);
  back := CreateCommand('Back', CM_BACK, 2);
  AddCommand(ok);
  AddCommand(back);
  repeat
    Delay(100);
    cmd := GetClickedCommand;
  until (cmd = ok) or (cmd = back);
  if cmd = ok then
  begin
    s := GetFormTitle + ': ' + FormGetText(nameField) + ', level ' + FormGetValue(gauge)
      + ', mode ' + ChoiceGetSelectedIndex(choice) + ', form? ' + ChoiceIsSelected(choice, 1)
      + ', date ' + GetYear(FormGetDate(dateField));
    FormSetText(nameField, Upcase(FormGetText(nameField)));
    FormSetValue(gauge, 10);
    FormRemove(note);
    Debug(s);
    ShowAlert('Result', s, tile, ALERT_INFO);
    PlayAlertSound;
    closed := CreateCommand('Close', CM_OK, 1);
    AddCommand(closed);
    repeat
      Delay(100);
    until GetClickedCommand = closed;
    RemoveCommand(closed);
  end;
  RemoveCommand(ok);
  RemoveCommand(back);
  RemoveFormTitle;
  ClearForm;
  ShowMenu('Pick one', CH_IMPLICIT);
  item := MenuAppendString('canvas');
  item := MenuAppendStringImage('form', tile);
  done := CreateCommand('Done', CM_OK, 1);
  AddCommand(done);
  repeat
    Delay(100);
  until GetClickedCommand = done;
  Debug('menu: ' + MenuGetSelectedIndex + ' ' + MenuIsSelected(0));
  RemoveCommand(done);
  ShowTextBox('Text box', 'edit me', 64, TF_ANY);
  ok := CreateCommand('OK', CM_OK, 1);
  AddCommand(ok);
  repeat
    Delay(100);
  until GetClickedCommand = ok;
  Debug('text box: ' + GetTextBoxString);
  RemoveCommand(ok);
  Check('empty command', EmptyCommand <> ok);
  ShowCanvas;
end;

{ ------------------------------------------------------------- http (2) }

procedure HttpDemo;
var
  conn: http;
  status: integer;
  body: string;
begin
  Cls;
  DrawText('GET http://example.com/ ...', 0, 0);
  Repaint;
  if OpenHttp(conn, 'http://example.com/') then
  begin
    SetHttpMethod(conn, GET);
    AddHttpHeader(conn, 'User-Agent', 'MIDletPascal SelfTest');
    AddHttpBody(conn, '');
    status := SendHttpMessage(conn);
    body := GetHttpResponse(conn);
    DrawText('status ' + status + ', ' + Length(body) + ' bytes', 0, 16);
    DrawText('type: ' + GetHttpHeader(conn, 'Content-Type'), 0, 32);
    Check('http open', IsHttpOpen(conn));
    CloseHttp(conn);
  end
  else
    DrawText('could not open', 0, 16);
  DrawText('any key to go back', 0, 48);
  Repaint;
  repeat
    Delay(100);
  until GetKeyClicked <> KE_NONE;
end;

{ ----------------------------------------------------------- player (3) }

procedure PlayerDemo;
var
  looped: boolean;
begin
  Cls;
  DrawText('tone, then /beep.wav', 0, 0);
  Repaint;
  PlayTone(60, 300, 100);
  Delay(400);
  if OpenPlayer('/beep.wav', 'audio/x-wav') then
  begin
    looped := SetPlayerCount(2);
    if StartPlayer then
      DrawText('playing ' + GetPlayerDuration + ' ms', 0, 16)
    else
      DrawText('could not start', 0, 16);
    Delay(1500);
    StopPlayer;
  end
  else
    DrawText('no player for it', 0, 16);
  DrawText('any key to go back', 0, 48);
  Repaint;
  repeat
    Delay(100);
  until GetKeyClicked <> KE_NONE;
end;

{ -------------------------------------------------------------- sms (4) }

procedure SmsDemo;
begin
  Cls;
  DrawText('sending an sms to 1234', 0, 0);
  Repaint;
  if SmsStartSend('1234', 'MIDletPascal SelfTest') then
  begin
    while SmsIsSending do
      Delay(100);
    DrawText('sent: ' + SmsWasSuccessfull, 0, 16);
  end
  else
    DrawText('could not start', 0, 16);
  DrawText('any key to go back', 0, 48);
  Repaint;
  repeat
    Delay(100);
  until GetKeyClicked <> KE_NONE;
end;

{ ------------------------------------------------------------- summary }

procedure DrawSummary;
var
  i, line: integer;
begin
  Cls;
  line := GetStringHeight('x');
  DrawText('checks: ' + (passed + failed) + ', failed: ' + failed, 0, 0);
  for i := 1 to failed do
    if i <= MAX_FAILS then
    begin
      SetColor(255, 80, 80);
      DrawText(failNames[i], 0, line * i);
    end;
  SetColor(255, 255, 255);
  DrawText('1 forms  2 http  3 player', 0, GetHeight - line * 3);
  DrawText('4 sms  5 drawing  0 quit', 0, GetHeight - line * 2);
  Repaint;
end;

begin
  Randomize;
  passed := 0;
  failed := 0;
  TestIntegers;
  TestStrings;
  TestBooleans;
  TestReals;
  TestArrays;
  TestRecords;
  TestControlFlow;
  TestBytecode;
  TestRecordStore;
  TestResources;
  TestTime;
  repeat
    DrawSummary;
    key := GetKeyClicked;
    if key = KE_KEY1 then
      FormsDemo
    else if key = KE_KEY2 then
      HttpDemo
    else if key = KE_KEY3 then
      PlayerDemo
    else if key = KE_KEY4 then
      SmsDemo
    else if key = KE_KEY5 then
      DrawingDemo
    else if key = KE_KEY0 then
      break;
    Delay(50);
  forever;
  Halt;
end.
