unit DUnitX.Tests.TestNameParser;

interface

uses
  DUnitX.TestFrameWork;

type
  [TestFixture]
  TTestNameParserTests = class
  public

    [TestCase('SingleName','Test.Namespace.Fixture.Method')]
    [TestCase('SingleName','Test.Namespace.Fixture.Method,')]
    [TestCase('SingleName','  Test.Namespace.Fixture.Method  ')]
    [TestCase('SingleName','  Test.Namespace.Fixture.Method  ,')]
    [TestCase('SingleName','Test.Namespace.Fixture.Method()')]
    [TestCase('SingleName','Test.Namespace.Fixture.Method(''string,argument'')')]
    [TestCase('SingleName','Test.Namespace.Fixture.Method(1,2,3)')]
    [TestCase('SingleName','Test.Namespace.Fixture.Method<int,int>()')]
    [TestCase('SingleName','Test.Namespace.Fixture.Method(")")')]
    procedure SingleName(const name : string);

    [TestCase('TwoNames','Test.Namespace.Fixture.Method1|Test.Namespace.Fixture.Method2','|')]
    [TestCase('TwoNames','Test.Namespace.Fixture.Method1|Test.Namespace.Fixture.Method2,','|')]
    [TestCase('TwoNames','Test.Namespace.Fixture.Method1(1,2)|Test.Namespace.Fixture.Method2(3,4)','|')]
    [TestCase('TwoNames','Test.Namespace.Fixture.Method1("(")|Test.Namespace.Fixture.Method2("<")','|')]
    procedure TwoNames(const name1 : string;const name2 : string);
  end;

implementation

uses
  System.SysUtils,
  DUnitX.TestNameParser;

{ TTestNameParserTests }

procedure TTestNameParserTests.SingleName(const name: string);
var
  names : TArray<string>;
begin
  names := TTestNameParser.Parse(name);
  Assert.AreEqual<Integer>(1,Length(names));
  Assert.AreEqual(Trim(name), names[0]);
end;

procedure TTestNameParserTests.TwoNames(const name1, name2: string);
var
  names : TArray<string>;
begin
  names := TTestNameParser.Parse(name1 + ',' + name2);
  Assert.AreEqual<Integer>(2, Length(names));
  Assert.AreEqual(Trim(name1), names[0]);
  Assert.AreEqual(Trim(name2), names[1]);
end;

end.
