﻿{***************************************************************************}
{                                                                           }
{           DUnitX                                                          }
{                                                                           }
{           Copyright (C) 2013 Vincent Parrett                              }
{                                                                           }
{           vincent@finalbuilder.com                                        }
{           http://www.finalbuilder.com                                     }
{                                                                           }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{ This unit is contains ideas borrowed largely from NUnit                   }
{ Copyright © 2012-2014 Charlie Poole                                       }
{ License  : http://nunit.org/index.php?p=vsTestAdapterLicense&r=2.6.3      }
{                                                                           }
{***************************************************************************}

unit DUnitX.TestFramework;

interface

uses
  Classes,
  SysUtils,
  TypInfo,
  Rtti,
  TimeSpan,
  DUnitX.Generics,
  DUnitX.Extensibility,
  DUnitX.Filters,
  Generics.Collections;

//TODO: Automatic support for https://code.google.com/p/delphi-code-coverage/ would be cool

{$I DUnitX.inc}

type
  ///	<summary>
  ///	  A class decorated with this attribute will be tested. The parameters
  ///	  allow you to control which methods are treated as tests. By default 
  ///	  only methods decorated with the Test attribute are run as tests.
  ///	</summary>
  TestFixtureAttribute = class(TCustomAttribute)
  private
    FName : string;
    FDescription : string;
  public
    constructor Create;overload;
    constructor Create(const AName : string);overload;
    constructor Create(const AName : string; const ADescription : string);overload;
    property Name : string read FName;
    property Description : string read FDescription;
  end;


  ///	<summary>
  ///	  A TestFixture decorated with this attribute will be tested using it's
  ///	  own thread.  This can speed up unit testing when fixtures do not
  ///	  compete for resources and the test machine has enough cores to service
  ///	  the tests.
  ///	</summary>
  ///	<remarks>
  ///	  NOTE - CURRENTLY PLANNED BUT NOT IMPLEMENTED!!!
  ///	</remarks>
  TestInOwnThreadAttribute = class(TCustomAttribute);

  ///	<summary>
  ///	  A method marked with this attribute will run before any tests in.  Note
  ///	  that if more than one method is decorated with this attribute the first
  ///	  method found will be executed (not recommended!).
  ///	</summary>
  SetupFixtureAttribute = class(TCustomAttribute)
  end;


  ///	<summary>
  ///	  A method on a test fixture decorated with this attribute will run
  ///	  before each test method is run. Note that if more than one method is
  ///	  decorated with this attribute the first method found will be executed
  ///	  (not recommended!).
  ///	</summary>
  SetupAttribute = class(TCustomAttribute)
  end;


  ///	<summary>
  ///	  A method on a test fixture class decorated with this attribute will be
  ///	  run after each test method is run. Note that if more than one method is
  ///	  decorated with this attribute the first method found will be executed
  ///	  (not recommended!).
  ///	</summary>
  TearDownAttribute = class(TCustomAttribute)
  end;


  ///	<summary>
  ///	  A method marked with this attribute can contain a teardown method that
  ///	  will be run after each all tests in the fixture have executed.  Note
  ///	  that if more than one method is decorated with this attribute the first
  ///	  method found will be executed (not recommended!).
  ///	</summary>
  TearDownFixtureAttribute = class(TCustomAttribute)
  end;

  ///	<summary>
  ///	    This attribue is applied to test methods.
  ///	    If a test is successful and produces a memory leak it will be
  ///	    reported.   If you do not want the leak reported, then you can add
  ///	    this attribute to the test method.
  ///	</summary>
  IgnoreMemoryLeaks = class(TCustomAttribute)
  private
    FIgnoreMemoryLeaks : Boolean;
  public
    constructor Create(const AIgnoreMemoryLeaks : Boolean = True);
    property IgnoreMemoryLeaks : Boolean read FIgnoreMemoryLeaks;
  end;


  ///	<summary>
  ///	  This attribute marks a method as a test method
  ///	</summary>
  TestAttribute = class(TCustomAttribute)
  private
    FEnabled : boolean;
  public
    constructor Create;overload;
    constructor Create(const AEnabled : boolean);overload;
    property Enabled : boolean read FEnabled;
  end;

  ///	<summary>
  ///	 This attribute allows you to specify a test Category
  ///  which can be used when filtering the tests to run.
  ///	</summary>
  CategoryAttribute = class(TCustomAttribute)
  private
    FCategory : string;
  public
    constructor Create(const ACategory : string);
    property Category : string read FCategory;
  end;


  ///	<summary>
  ///	  This attribute will prevent a test from being run.   It will still show
  ///	  up in the lists of tests, and reported as an Ignored test
  ///	</summary>
  ///	<remarks>
  ///	  This is useful when you need to temporarily stop a test from running.
  ///	</remarks>
  IgnoreAttribute = class(TCustomAttribute)
  private
    FReason : string;
  public
    constructor Create(const AReason : string = '');
    property Reason : string read FReason;
  end;


  ///	<summary>
  ///	  Marks a test method to be repeated count times.
  ///	</summary>
  ///	<remarks>
  ///	  If [RepeatTest(0]] used then the test will be skipped
  ///   and behaves like IgnoreAttribute
  ///	</remarks>
  RepeatTestAttribute = class(TCustomAttribute)
  private
    FCount : Cardinal;
  public
    constructor Create(const ACount : Cardinal);
    property Count : Cardinal read FCount;
  end;

  TValueArray = DUnitX.Extensibility.TValueArray;


  ///	<summary>
  ///	  Internal Structure used for those implementing CustomTestCase or
  ///	  CustomTestCaseSource descendants.
  ///	</summary>
  TestCaseInfo = record

    ///	<summary>
    ///	  Name of the Test Case
    ///	</summary>
    Name : string;

    ///	<summary>
    ///	  Values that will be passed to the method being tested.
    ///	</summary>
    Values : TValueArray;
  end;

  TestCaseInfoArray = array of TestCaseInfo;


  ///	<summary>
  ///	  Base class for all Test Case Attributes.   
  ///	</summary>
  ///	<remarks>
  ///	  Class is abstract and should never be, used to annotate a class as a
  ///	  attribute.   Instead use a descendant, that implements the GetCaseInfo
  ///	  method.
  ///	</remarks>
  CustomTestCaseAttribute = class abstract(TCustomAttribute)
  protected
    function GetCaseInfo : TestCaseInfo;  virtual; abstract;
  public
    property CaseInfo : TestCaseInfo read GetCaseInfo;
  end;

  ///	<summary>
  ///	  Base class for all Test Case Source Attributes.   
  ///	</summary>
  ///	<remarks>
  ///	  <para>
  ///	    Class is abstract and should never be, used to annotate a class as a
  ///	    attribute.   Instead use a descendant, that implements the
  ///	    GetCaseInfoArray method.    
  ///	  </para>
  ///	  <para>
  ///	    Note: If a method is annotated with a decendant of
  ///	    TestCaseSourceAttribute and returns an empty TestCaseInfoArray, then
  ///	    no test will be shown for the method.
  ///	  </para>
  ///	</remarks>
  CustomTestCaseSourceAttribute = class abstract(TCustomAttribute)
  protected
    function GetCaseInfoArray : TestCaseInfoArray; virtual; abstract;
  public
    property CaseInfoArray : TestCaseInfoArray read GetCaseInfoArray;
  end;


  ///	<summary>
  ///	  The TestCaseAttribute allows you to pass values to a test function.
  ///	  Each value is delimited in the string, by default the delimiter is ','
  ///	</summary>
  TestCaseAttribute = class(CustomTestCaseAttribute)
  protected
    FCaseInfo : TestCaseInfo;
    function GetCaseInfo : TestCaseInfo; Override;
    function GetName: String;
    function GetValues: TValueArray;
  public
    constructor Create(const ACaseName : string; const AValues : string;const ASeperator : string = ',');overload;
    property Name : String read GetName;
    property Values : TValueArray read GetValues;
  end;

  TTestMethod = DUnitX.Extensibility.TTestMethod;

  TTestLocalMethod = reference to procedure;

  {$SCOPEDENUMS ON}
  TLogLevel = (Information, Warning, Error);
  {$SCOPEDENUMS OFF}

const
  TLogLevelDesc : array[TLogLevel] of string = ('Info', 'Warn', 'Err');

type
{$IFDEF DELPHI_XE2_UP}
  ///	<summary>
  ///	  This helper class is intended to redirect the writeln method to a test
  ///	  runner so that it is logged correctly.
  ///	</summary>
  TTestFixtureHelper = class helper for TObject
  public
    procedure Log(const logType : TLogLevel; const msg : string);overload;
    procedure Log(const msg : string);overload;
    //for backwards compatibilty with DUnit tests.
    procedure Status(const msg : string);
    //redirects WriteLn to our loggers.
    procedure WriteLn(const msg : string);overload;
    procedure WriteLn;overload;
  end;
{$ENDIF}



  Assert = class
  private
    class procedure CheckExceptionClass(E: Exception; const exceptionClass: ExceptClass);
    class procedure CheckExceptionClassDescendant(E: Exception; const exceptionClass: ExceptClass);
    class function AddLineBreak(const msg: string): string;
  public
    class procedure Pass(const message : string = '');
    class procedure Fail(const message : string = ''; const errorAddrs : pointer = nil);

    class procedure AreEqual(const expected : string; const actual : string; const ignoreCase : boolean; const message : string = '');overload;
    class procedure AreEqual(const expected : string; const actual : string; const message : string = '');overload;
    class procedure AreEqual(const expected, actual : Double; const tolerance : Double; const message : string = '');overload;
    class procedure AreEqual(const expected, actual : Double; const message : string = '');overload;
    class procedure AreEqual(const expected, actual : Extended; const tolerance : Extended; const message : string = '');overload;
    class procedure AreEqual(const expected, actual : Extended; const message : string = '');overload;
    class procedure AreEqual(const expected, actual : TClass; const message : string = '');overload;
{$IFDEF DELPHI_XE_UP}
    //Delphi 2010 compiler bug breaks this
    class procedure AreEqual<T>(const expected, actual : T; const message : string = '');overload;
{$ENDIF}
    class procedure AreEqual(const expected, actual : Integer; const message : string = '');overload;
    class procedure AreEqual(const expected, actual : boolean; const message : string = '');overload;

    class procedure AreEqualMemory(const expected : Pointer; const actual : Pointer; const size : Cardinal; const message : string = '');

    class procedure AreNotEqual(const expected : string; const actual : string; const ignoreCase : boolean = true; const message : string = '');overload;

    class procedure AreNotEqual(const expected, actual : Extended; const tolerance : Extended; const message : string = '');overload;
    class procedure AreNotEqual(const expected, actual : Extended; const message : string = '');overload;

    class procedure AreNotEqual(const expected, actual : Double; const tolerance : double; const message : string = '');overload;
    class procedure AreNotEqual(const expected, actual : Double; const message : string = '');overload;

    class procedure AreNotEqual(const expected, actual : TClass; const message : string = '');overload;
{$IFDEF DELPHI_XE_UP}
    //Delphi 2010 compiler bug breaks this
    class procedure AreNotEqual<T>(const expected, actual : T; const message : string = '');overload;
{$ENDIF}
    class procedure AreNotEqual(const expected, actual : Integer; const message : string = '');overload;
    class procedure AreNotEqualMemory(const expected : Pointer; const actual : Pointer; const size : Cardinal; const message : string = '');

    class procedure AreSame(const expected, actual : TObject; const message : string = '');overload;
    class procedure AreSame(const expected, actual : IInterface; const message : string = '');overload;

    class procedure AreNotSame(const expected, actual : TObject; const message : string = '');overload;
    class procedure AreNotSame(const expected, actual : IInterface; const message : string = '');overload;

{$IFDEF DELPHI_XE_UP}
    //Delphi 2010 compiler bug breaks this
    class procedure Contains<T>(const list : IEnumerable<T>; const value : T; const message : string = '');overload;
    class procedure Contains<T>(const arr : array of T; const value : T; const message : string = '');overload;
    class procedure DoesNotContain<T>(const list : IEnumerable<T>; const value : T; const message : string = '');overload;
    class procedure DoesNotContain<T>(const arr : array of T; const value : T; const message : string = '');overload;
{$ENDIF}
    class procedure Implements<T : IInterface>(value : IInterface; const message : string = '' );
    class procedure IsTrue(const condition : boolean; const message : string = '');
    class procedure IsFalse(const condition : boolean; const message : string = '');

    class procedure IsNull(const condition : TObject; const message : string = '');overload;
    class procedure IsNull(const condition : Pointer; const message : string = '');overload;
    class procedure IsNull(const condition : IInterface; const message : string = '');overload;
    class procedure IsNull(const condition : Variant; const message : string = '');overload;

    class procedure IsNotNull(const condition : TObject; const message : string = '');overload;
    class procedure IsNotNull(const condition : Pointer; const message : string = '');overload;
    class procedure IsNotNull(const condition : IInterface; const message : string = '');overload;
    class procedure IsNotNull(const condition : Variant; const message : string = '');overload;

    class procedure IsEmpty(const value : string; const message : string = '');overload;
    class procedure IsEmpty(const value : Variant; const message : string = '');overload;
    class procedure IsEmpty(const value : TStrings; const message : string = '');overload;
    class procedure IsEmpty(const value : TList; const message : string = '');overload;
    class procedure IsEmpty(const value : IInterfaceList; const message : string = '');overload;
{$IFDEF DELPHI_XE_UP}
    //Delphi 2010 compiler bug breaks this
    class procedure IsEmpty<T>(const value : IEnumerable<T>; const message : string = '');overload;
{$ENDIF}

    class procedure IsNotEmpty(const value : string; const message : string = '');overload;
    class procedure IsNotEmpty(const value : Variant; const message : string = '');overload;
    class procedure IsNotEmpty(const value : TStrings; const message : string = '');overload;
    class procedure IsNotEmpty(const value : TList; const message : string = '');overload;
    class procedure IsNotEmpty(const value : IInterfaceList; const message : string = '');overload;
{$IFDEF DELPHI_XE_UP}
    //Delphi 2010 compiler bug breaks this
    class procedure IsNotEmpty<T>(const value : IEnumerable<T>; const message : string = '');overload;
{$ENDIF}

    /// <summary>
    ///   Checks that an exception exactly matching ExceptClass will be raised.
    /// </summary>
    class procedure WillRaise(const AMethod : TTestLocalMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;
    /// <summary>
    ///   Checks that an exception exactly matching ExceptClass and Message will be raised.
    /// </summary>
    class procedure WillRaiseWithMessage(const AMethod : TTestLocalMethod; const exceptionClass : ExceptClass = nil; const exceptionMsg: string = ''; const msg : string = ''); overload;
    /// <summary>
    ///   Checks that an exception exactly matching ExceptClass will be raised.
    /// </summary>
    class procedure WillRaise(const AMethod : TTestMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;

    /// <summary>
    ///   Checks that an exception that descends from ExceptClass will be raised.
    /// </summary>
    class procedure WillRaiseDescendant(const AMethod : TTestLocalMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;
    /// <summary>
    ///   Checks that an exception that descends from ExceptClass will be raised.
    /// </summary>
    class procedure WillRaiseDescendant(const AMethod : TTestMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;

    /// <summary>
    ///   Checks that an exception will be raised.
    /// </summary>
    class procedure WillRaiseAny(const AMethod : TTestLocalMethod; const msg : string = ''); overload;
    /// <summary>
    ///   Checks that an exception will be raised.
    /// </summary>
    class procedure WillRaiseAny(const AMethod : TTestMethod;  const msg : string = ''); overload;


    /// <summary>
    ///   Checks that an exception exactly matching ExceptClass will not be raised.
    /// </summary>
    class procedure WillNotRaise(const AMethod : TTestLocalMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;
    /// <summary>
    ///   Checks that an exception exactly matching ExceptClass will not be raised.
    /// </summary>
    class procedure WillNotRaise(const AMethod : TTestMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;

    /// <summary>
    ///   Checks that an exception that descends from ExceptClass not will be raised.
    /// </summary>
    class procedure WillNotRaiseDescendant(const AMethod : TTestLocalMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;
    /// <summary>
    ///   Checks that an exception that descends from ExceptClass not will be raised.
    /// </summary>
    class procedure WillNotRaiseDescendant(const AMethod : TTestMethod; const exceptionClass : ExceptClass = nil; const msg : string = ''); overload;

    /// <summary>
    ///   Checks that an exception of Any type not will be raised. This method
    ///   is to complement <see cref="DUnitX.TestFramework|Assert.WillRaiseAny(TTestLocalMethod,string)">
    ///   WillRaiseAny</see> method, and is not required, as the default behavior of a test
    ///   is to fail when any exception is raised.
    /// </summary>
    class procedure WillNotRaiseAny(const AMethod : TTestLocalMethod; const msg : string = ''); overload;
    /// <summary>
    ///   Checks that an exception of Any type not will be raised. This method
    ///   is to complement <see cref="DUnitX.TestFramework|Assert.WillRaiseAny(TTestMethod,string)">
    ///   WillRaiseAny</see> method, and is not required, as the default behavior of a test
    ///   is to fail when any exception is raised.
    /// </summary>
    class procedure WillNotRaiseAny(const AMethod : TTestMethod; const msg : string = ''); overload;

    class procedure Contains(const theString : string; const subString : string; const ignoreCase : boolean = true; const message : string = '');overload;
    class procedure StartsWith(const theString : string; const subString : string;const ignoreCase : boolean = true; const message : string = '');
    class procedure EndsWith(const theString : string; const subString : string;const ignoreCase : boolean = true; const message : string = '');
    class procedure InheritsFrom(const descendant : TClass; const parent : TClass; const message : string = '');
{$IFDEF DELPHI_XE_UP}
    //Delphi 2010 compiler bug breaks this
    class procedure IsType<T>(const value : T; const message : string = '');overload;deprecated 'use inheritsfrom - istype is useless';
{$ENDIF}

    {$IFDEF SUPPORTS_REGEX}
    class procedure IsMatch(const regexPattern : string; const theString : string; const message : string = '');
    {$ENDIF}
  end;

  {$M+}
  ITestFixtureInfo = interface;
  {$M-}

  {$M+}
  ITestInfo = interface
    ['{FF61A6EB-A76B-4BE7-887A-598EBBAE5611}']
    function GetName : string;
    function GetFullName : string;
    function GetCategories : TList<string>;
    function GetActive : boolean;
    function GetTestFixture : ITestFixtureInfo;

    function GetTestStartTime : TDateTime;
    function GetTestEndTime : TDateTime;
    function GetTestDuration : TTimeSpan;

    function GetEnabled : boolean;
    procedure SetEnabled(const value : boolean);

    property Name : string read GetName;
    property FullName : string read GetFullName;
    property Enabled : boolean read GetEnabled write SetEnabled;
    property Categories : TList<string> read GetCategories;

    property Active : boolean read GetActive;
    property Fixture : ITestFixtureInfo read GetTestFixture;
  end;

  ITestInfoList = interface(IList<ITestInfo>)
    ['{1C614DC2-537F-4229-863D-669E4211074E}']
  end;

  TTestInfoList = class(TDUnitXList<ITestInfo>, ITestInfoList);
  {$M-}

  {$M+}
  ITestFixtureInfo = interface
    ['{9E98B1E8-583A-49FC-B409-9B6937E22E81}']
    function GetName  : string;
    function GetNameSpace : string;
    function GetFullName : string;
    function GetCategories : TList<string>;
    function GetDescription : string;
    function GetTests : IList<ITestInfo>;
    function GetTestClass : TClass;
    function GetSetupMethodName : string;
    function GetSetupFixtureMethodName : string;
    function GetTearDownMethodName : string;
    function GetTearDownFixtureMethodName : string;
    function GetTestInOwnThread : boolean;
    function GetHasChildren : boolean;

    function GetTestCount : cardinal;
    function GetActiveTestCount : cardinal;

    property Name                       : string read GetName;
    property NameSpace                  : string read GetNameSpace;
    property FullName                   : string read GetFullName;
    property Description                : string read GetDescription;
    property HasChildFixtures           : boolean read GetHasChildren;
    property TestClass                  : TClass read GetTestClass;
    property Tests                      : IList<ITestInfo> read GetTests;
    property SetupMethodName            : string read GetSetupMethodName;
    property SetupFixtureMethodName     : string read GetSetupFixtureMethodName;
    property TearDownMethodName         : string read GetTearDownMethodName;
    property TearDownFixtureMethodName  : string read GetTearDownFixtureMethodName;
    property TestInOwnThread            : boolean read GetTestInOwnThread;
    property Categories                 : TList<string> read GetCategories;

    property TestCount                  : cardinal read GetTestCount;
    property ActiveTestCount            : cardinal read GetActiveTestCount;
  end;

  ITestFixtureInfoList = interface(IList<ITestFixtureInfo>)
    ['{DEE229E7-1450-4DC1-BEEA-562461439084}']
  end;
  {$M-}
  TTestFixtureInfoList = class(TDUnitXList<ITestFixtureInfo>, ITestFixtureInfoList);

  {$M+}
  IResult = interface
  ['{AEA1E458-157B-4B3A-9474-44EDFB3EE7A1}']
    function GetStartTime : TDateTime;
    function GetFinishTime : TDateTime;
    function GetDuration : TTimeSpan;

    //Timing
    property StartTime : TDateTime read GetStartTime;
    property FinishTime : TDateTime read GetFinishTime;
    property Duration : TTimeSpan read GetDuration;
  end;
  {$M-}


  {$SCOPEDENUMS ON}
  TTestResultType = (Pass,Failure,Error,Ignored,MemoryLeak);
  {$M+}
  ITestResult = interface(IResult)
  ['{EFD44ABA-4F3E-435C-B8FC-1F8EB4B35A3B}']
    function GetTest : ITestInfo;
    function GetResult : boolean;
    function GetResultType : TTestResultType;
    function GetMessage : string;
    function GetStackTrace : string;

    //Test
    property Test : ITestInfo read GetTest;

    //Results
    property Result : boolean read GetResult;
    property ResultType : TTestResultType read GetResultType;
    property Message : string read GetMessage;
    property StackTrace : string read GetStackTrace;

  end;
  {$M-}

  ITestError = interface(ITestResult)
  ['{375941C6-CEFD-44E5-9646-30D7915B8A71}']
    function GetExceptionClass : ExceptClass;
    function GetExceptionMessage : string;
    function GetExceptionLocationInfo : string;
    function GetExceptionAddressInfo : string;

    property ExceptionClass : ExceptClass read GetExceptionClass;
    property ExceptionMessage : string read GetExceptionMessage;
    property ExceptionLocationInfo : string read GetExceptionLocationInfo;
    property ExceptionAddressInfo : string read GetExceptionAddressInfo;
  end;

  IFixtureResult = interface(IResult)
  ['{7264579D-495E-4E00-A15D-751E6A65BEF6}']
    function GetErrorCount        : integer;
    function GetFailureCount      : integer;
    function GetIgnoredCount      : integer;
    function GetPassCount      : integer;
    function GetHasFailures       : boolean;
    function GetTestResultCount   : integer;
    function GetChildCount        : integer;

    function GetFixture           : ITestFixtureInfo;
    function GetTestResults       : IList<ITestResult>;
    function GetChildren          : IList<IFixtureResult>;
    function GetFailures  : IList<ITestResult>;
    function GetErrors    : IList<ITestError>;
    function GetPasses : IList<ITestResult>;
    function GetName : string;
    function GetNamespace : string;
    procedure Reduce;

    property HasFailures  : Boolean read GetHasFailures;
    property FailureCount : integer read GetFailureCount;
    property ErrorCount   : integer read GetErrorCount;
    property IgnoredCount : integer read GetIgnoredCount;
    property PassCount    : integer read GetPassCount;
    property ResultCount  : integer read GetTestResultCount;
    property ChildCount   : integer read GetChildCount;

    property Name         : string read GetName;
    property Namespace    : string read GetNamespace;
    property Fixture      : ITestFixtureInfo read GetFixture;
    property Children     : IList<IFixtureResult> read GetChildren;
    property TestResults  : IList<ITestResult> read GetTestResults;
    property Failures     : IList<ITestResult> read GetFailures;
    property Errors       : IList<ITestError> read GetErrors;
    property Pesses       : IList<ITestResult> read GetPasses;
  end;


  {$M+}
  IRunResults = interface(IResult)
  ['{4A335B76-33E3-48FD-87DF-9462428C60DA}']
    function GetFixtureCount : integer;
    function GetTestCount : integer;
    function GetAllPassed : boolean;
    function GetFailureCount : integer;
    function GetErrorCount : integer;
    function GetMemoryLeakCount : Integer;
    function GetPassCount : integer;
    function GetIgnoredCount : integer;
    function GetSuccessRate : integer;

    function GetFixtureResults : IEnumerable<IFixtureResult>;

    function GetAllTestResults : IEnumerable<ITestResult>;

    function ToString : string;

    property TestCount : integer read GetTestCount;
    property FixtureCount : integer read GetFixtureCount;

    property FailureCount : integer read GetFailureCount;
    property ErrorCount : integer read GetErrorCount;
    property IgnoredCount : integer read GetIgnoredCount;
    property PassCount : integer read GetPassCount;
    property MemoryLeakCount : integer read GetMemoryLeakCount;

    property SuccessRate : integer read GetSuccessRate;
    //means all enabled/not ingored tests passed.
    property AllPassed : boolean read GetAllPassed;

    property FixtureResults : IEnumerable<IFixtureResult> read GetFixtureResults;
  end;
  {$M-}

  ITestLogger = interface
    ['{AADCA392-421C-4060-8D47-79D7CAAB0EEF}']

    ///	<summary>
    ///	  Called at the start of testing. The default console logger prints the
    ///	  DUnitX banner.
    ///	</summary>
    procedure OnTestingStarts(const threadId, testCount, testActiveCount : Cardinal);

    ///	<summary>
    ///	  //Called before a Fixture is run.
    ///	</summary>
    procedure OnStartTestFixture(const threadId : Cardinal; const fixture : ITestFixtureInfo);

    ///	<summary>
    ///	  //Called before a fixture Setup method is run
    ///	</summary>
    procedure OnSetupFixture(const threadId : Cardinal; const fixture : ITestFixtureInfo);

    ///	<summary>
    ///	  Called after a fixture setup method is run.
    ///	</summary>
    procedure OnEndSetupFixture(const threadId : Cardinal; const fixture : ITestFixtureInfo);

    ///	<summary>
    ///	  Called before a Test method is run.
    ///	</summary>
    procedure OnBeginTest(const threadId : Cardinal;const  Test: ITestInfo);

    ///	<summary>
    ///	  Called before a test setup method is run.
    ///	</summary>
    procedure OnSetupTest(const threadId : Cardinal;const  Test: ITestInfo);

    ///	<summary>
    ///	  Called after a test setup method is run.
    ///	</summary>
    procedure OnEndSetupTest(const threadId : Cardinal;const  Test: ITestInfo);

    ///	<summary>
    ///	  Called before a Test method is run.
    ///	</summary>
    procedure OnExecuteTest(const threadId : Cardinal;const  Test: ITestInfo);

    ///	<summary>
    ///	  Called when a test succeeds
    ///	</summary>
    procedure OnTestSuccess(const threadId : Cardinal;const  Test: ITestResult);

    ///	<summary>
    ///	  Called when a test errors.
    ///	</summary>
    procedure OnTestError(const threadId : Cardinal;const Error: ITestError);

    ///	<summary>
    ///	  Called when a test fails.
    ///	</summary>
    procedure OnTestFailure(const threadId : Cardinal;const  Failure: ITestError);

    ///	<summary>
    ///	  //called when a test is ignored.
    ///	</summary>
    procedure OnTestIgnored(const threadId : Cardinal; const AIgnored: ITestResult);

    ///	<summary>
    ///	  //called when a test memory leaks.
    ///	</summary>
    procedure OnTestMemoryLeak(const threadId : Cardinal; const Test: ITestResult);

    ///	<summary>
    ///	  //allows tests to write to the log.
    ///	</summary>
    procedure OnLog(const logType : TLogLevel; const msg : string);

    ///	<summary>
    ///	  //called before a Test Teardown method is run.
    ///	</summary>
    procedure OnTeardownTest(const threadId : Cardinal;const  Test: ITestInfo);

    ///	<summary>
    ///	  //called after a test teardown method is run.
    ///	</summary>
    procedure OnEndTeardownTest(const threadId : Cardinal; const Test: ITestInfo);

    ///	<summary>
    ///	  //called after a test method and teardown is run.
    ///	</summary>
    procedure OnEndTest(const threadId : Cardinal;const  Test: ITestResult);

    ///	<summary>
    ///	  //called before a Fixture Teardown method is called.
    ///	</summary>
    procedure OnTearDownFixture(const threadId : Cardinal; const fixture : ITestFixtureInfo);

    ///	<summary>
    ///	  //called after a Fixture Teardown method is called.
    ///	</summary>
    procedure OnEndTearDownFixture(const threadId : Cardinal; const fixture : ITestFixtureInfo);

    ///	<summary>
    ///	  //called after a Fixture has run.
    ///	</summary>
    procedure OnEndTestFixture(const threadId : Cardinal; const results : IFixtureResult);

    ///	<summary>
    ///	  //called after all fixtures have run.
    ///	</summary>
    procedure OnTestingEnds(const RunResults: IRunResults);
  end;

  TDUnitXExitBehavior = (Continue, //The runner will exit normally
                         Pause //The runner will pause after displaying it's results
                         );

  ITestRunner = interface
    ['{06C0D8D2-B2D7-42F9-8D23-8F2D8A75263F}']
    procedure AddLogger(const value : ITestLogger);
    function GetUseRTTI : boolean;
    procedure SetUseRTTI(const value : boolean);

    //This is exposed for the GUI Runner cast as ITestFixtureList.
    function BuildFixtures : IInterface;

    function Execute : IRunResults;

    procedure Log(const logType : TLogLevel; const msg : string);overload;
    procedure Log(const msg : string);overload;
    //for backwards compatibilty with DUnit tests.
    procedure Status(const msg : string);
    //redirects WriteLn to our loggers.
    procedure WriteLn(const msg : string);overload;
    procedure WriteLn;overload;


    ///	<summary>
    ///	  When true, test fixtures will be found by using RTTI to search for
    ///	  classes decorated as TestFixtures.  Note for this to work you may
    ///	  need to use {$STRONGLINKTYPES ON} otherwise the classes may not get
    ///	  linked as they are not referenced. When False you will need to
    ///	  register the fixtures using TDUnitX.RegisterTestFixture
    ///	</summary>
    property UseRTTI : boolean read GetUseRTTI write SetUseRTTI;
  end;

  TDUnitXOptions = class
  private
    FXMLOutputFile : string;
    FRun : TStringList;
    FRunListFile : string;
    FInclude : string;
    FExclude : string;
    FLogLevel : TLogLevel;
    FHideBanner : boolean;
    FExitBehavior : TDUnitXExitBehavior;
    FShowUsage : boolean;
    FDontShowIgnored : boolean;
  public
    constructor Create;
    destructor Destroy;override;
    //The xml output file to be generated by xml loggers
    property XMLOutputFile : string read FXMLOutputFile write FXMLOutputFile;

    // Specifiy the tests to run.
    property Run : TStringList read FRun write FRun;

    //the name of a file which lists the tests to run.
    property RunListFile : string read FRunListFile write FRunListFile;

    //Category Include Pattern
    property Include : string read FInclude write FInclude;

    //Category Exlude Pattern
    property Exclude : string read FExclude write FExclude;

    property LogLevel : TLogLevel read FLogLevel write FLogLevel;

    //If true do not show the banner
    property HideBanner : boolean read FHideBanner write FHideBanner;

    //Defaults to Pause
    property ExitBehavior : TDUnitXExitBehavior read FExitBehavior write FExitBehavior;

    // Show command line usage
    property ShowUsage : boolean read FShowUsage write FShowUsage;

    //Don't run or show ignored tests at all
    property DontShowIgnored : boolean read FDontShowIgnored write FDontShowIgnored;
  end;


  TDUnitX = class
  private
    class var
      FOptions : TDUnitXOptions;
      FFilter : ITestFilter;
  protected
    class constructor Create;
    class destructor Destroy;
  public class var
    RegisteredFixtures : TDictionary<TClass,string>;
    RegisteredPlugins  : TList<IPlugin>;
  public
    class function CreateRunner : ITestRunner;overload;
    class function CreateRunner(const ALogger : ITestLogger) : ITestRunner;overload;
    class procedure RegisterTestFixture(const AClass : TClass; const AName : string = '' );
    class procedure RegisterPlugin(const plugin : IPlugin);
    class function CurrentRunner : ITestRunner;
    ///  Parses the command line options and applies them the the Options object.
    ///  Will throw exception if there are errors.
    class procedure CheckCommandLine;
    //   Container for all options supported
    class property Options : TDUnitXOptions read FOptions;
    //   This is the test filter used by the runners. It's here because we need to build it when checking the command line.
    class property Filter : ITestFilter read FFilter;
  end;

  // Register an implementation via TDUnitXIoC.DefaultContainer
  IStacktraceProvider = interface
  ['{382288B7-932C-4B6E-8417-660FFCA849EB}']
    function GetStackTrace(const ex: Exception; const exAddressAddress: Pointer) : string;
    function PointerToLocationInfo(const Addrs: Pointer): string;
    function PointerToAddressInfo(Addrs: Pointer): string;
  end;

  IMemoryLeakMonitor = interface
  ['{A374A4D0-9BF6-4E01-8A29-647F92CBF41C}']
    procedure PreSetup;
    procedure PostSetUp;
    procedure PreTest;
    procedure PostTest;
    procedure PreTearDown;
    procedure PostTearDown;

    function SetUpMemoryAllocated: Int64;
    function TearDownMemoryAllocated: Int64;
    function TestMemoryAllocated: Int64;
  end;


  ETestFrameworkException = class(Exception);

  ENotImplemented = class(ETestFrameworkException);

  //base exception for any internal exceptions which cause the test to stop
  EAbort = class(ETestFrameworkException);

  ETestFailure = class(EAbort);
  ETestPass = class(EAbort);
  ENoTestsRegistered = class(ETestFrameworkException);
  ECommandLineError = class(ETestFrameworkException);

{$IFDEF DELPHI_XE_DOWN}
  function ReturnAddress: Pointer; assembler;
{$ENDIF}

const
  EXIT_OK     = 0;
  EXIT_ERRORS = 1;
  EXIT_OPTIONS_ERROR = 100;

implementation

uses
  DUnitX.ConsoleWriter.Base,
  DUnitX.Banner,
  DUnitX.OptionsDefinition,
  DUnitX.CommandLine.Options,
  DUnitX.TestRunner,
  DUnitX.Utils,
  DUnitX.IoC,
  DUnitX.MemoryLeakMonitor.Default,
  DUnitX.FixtureProviderPlugin,
  DUnitX.FilterBuilder,
  Variants,
  Math,
  StrUtils,
  Types,
  {$IFDEF SUPPORTS_REGEX}
  RegularExpressions,
  {$ENDIF}
  Generics.Defaults;

function IsBadPointer(P: Pointer):Boolean;register;
begin
  try
    Result  := (p = nil) or ((Pointer(P^) <> P) and (Pointer(P^) = P));
  except
    Result := true;
  end
end;

{$IFDEF DELPHI_XE_DOWN}
function ReturnAddress: Pointer; assembler;
const
  CallerIP = $4;
asm
   mov   eax, ebp
   call  IsBadPointer
   test  eax,eax
   jne   @@Error

   mov   eax, [ebp].CallerIP
   sub   eax, 5   // 5 bytes for call

   push  eax
   call  IsBadPointer
   test  eax,eax
   pop   eax
   je    @@Finish

@@Error:
   xor eax, eax
@@Finish:
end;
{$ENDIF}

{ TestFixture }

constructor TestFixtureAttribute.Create(const AName: string);
begin
  FName := AName;
end;

constructor TestFixtureAttribute.Create;
begin

end;


constructor TestFixtureAttribute.Create(const AName: string; const ADescription : string);
begin
  FName := AName;
  FDescription := ADescription;
end;

{ Assert }

class procedure Assert.AreEqual(const expected, actual, tolerance: Extended; const message: string);
begin
  if not Math.SameValue(expected,actual,tolerance) then
    Fail(Format('Expected %g but got %g %s' ,[expected,actual,message]), ReturnAddress);
end;


class procedure Assert.AreEqual(const expected, actual: TClass; const message: string);
var
  msg : string;
begin
  if expected <> actual then
  begin
    msg := ' is not equal to ';
    if expected = nil then
      msg := 'nil' + msg
    else
      msg := expected.ClassName + msg;

    if actual = nil then
      msg := msg +  'nil'
    else
      msg := msg + actual.ClassName;

    if message <> '' then
      msg := msg + '. ' + message;

    Fail(msg, ReturnAddress);
  end;
end;

{$IFDEF DELPHI_XE_UP}
    //Delphi 2010 compiler bug breaks this
class procedure Assert.AreEqual<T>(const expected, actual: T; const message: string);
var
  comparer : IComparer<T>;
  expectedValue, actualValue : TValue;
begin
  comparer := TComparer<T>.Default;
  if comparer.Compare(actual,expected) <> 0 then
  begin
    expectedValue := TValue.From<T>(expected);
    actualValue := TValue.From<T>(actual);
    Fail(Format('Expected %s is not equal to actual %s %s', [expectedValue.ToString, actualValue.ToString, message]), ReturnAddress)
  end;
end;
{$ENDIF}

class function Assert.AddLineBreak(const msg: string): string;
begin
  if msg <> '' then
    Result :=  sLineBreak + msg
  else
    Result := '';
end;

class procedure Assert.AreEqual(const expected, actual: Integer; const message: string);
begin
  if expected <> actual then
    Fail(Format('Expected %d but got %d %s' ,[expected, actual, message]), ReturnAddress);
end;

class procedure Assert.AreEqual(const expected, actual, tolerance: Double; const message: string);
begin
  if not Math.SameValue(expected,actual,tolerance) then
    Fail(Format('Expected %g but got %g %s' ,[expected,actual,message]), ReturnAddress);
end;

class procedure Assert.AreEqual(const expected, actual: Double; const message: string);
var
  tolerance : Double;
begin
  tolerance := 0;
  AreEqual(expected, actual, tolerance, message);
end;

class procedure Assert.AreEqual(const expected, actual: Extended; const message: string);
var
  tolerance : Extended;
begin
  tolerance := 0;
  AreEqual(expected, actual, tolerance, message);
end;

class procedure Assert.AreEqualMemory(const expected : Pointer; const actual : Pointer; const size : Cardinal; const message : string);
begin
  if not CompareMem(expected, actual, size) then
    Fail('Memory values are not equal. ' + message, ReturnAddress);
end;

class procedure Assert.AreNotEqual(const expected, actual, tolerance: Extended; const message: string);
begin
  if Math.SameValue(expected, actual, tolerance) then
    Fail(Format('%g equals actual %g %s' ,[expected,actual,message]), ReturnAddress);
end;


class procedure Assert.AreNotEqual(const expected, actual: string;const ignoreCase: boolean; const message: string);

  function AreNotEqualText(const expected, actual: string; const ignoreCase: boolean): boolean;
  begin
    if ignoreCase then
      Result := SameText(expected, actual)
    else
      Result := SameStr(expected, actual);

  end;
begin
  if AreNotEqualText(expected, actual, ignoreCase) then
     Fail(Format('[%s] is Equal to [%s] %s', [expected, actual, message]), ReturnAddress);
end;

class procedure Assert.AreNotEqual(const expected, actual: TClass; const message: string);
var
  msg : string;
begin
  if expected = actual then
  begin
    msg := ' is equal to ';
    if expected = nil then
      msg := 'nil' + msg
    else
      msg := expected.ClassName + msg;

    if actual = nil then
      msg := msg +  'nil'
    else
      msg := msg + actual.ClassName;
    if message <> '' then
      msg := msg + '. ' + message;

    Fail(msg, ReturnAddress);
  end;
end;

{$IFDEF DELPHI_XE_UP}
//Delphi 2010 compiler bug breaks this
class procedure Assert.AreNotEqual<T>(const expected, actual: T; const message: string);
var
  comparer : IComparer<T>;
  expectedValue, actualValue : TValue;
begin
  comparer := TComparer<T>.Default;
  if comparer.Compare(actual,expected) = 0 then
  begin
    expectedValue := TValue.From<T>(expected);
    actualValue := TValue.From<T>(actual);

    Fail(Format('Expected %s equals actual %s %s',[expectedValue.ToString, actualValue.ToString, message]), ReturnAddress);
  end;
end;
{$ENDIF}

class procedure Assert.AreNotEqual(const expected, actual: Integer; const message: string);
begin
  if expected = actual then
    Fail(Format('Expected %d equals actual %d %s' ,[expected, actual, message]), ReturnAddress);
end;

class procedure Assert.AreNotEqual(const expected, actual: Extended; const message: string);
var
  tolerance : Extended;
begin
  tolerance := 0;
  Assert.AreNotEqual(expected,actual,tolerance,message);

end;

class procedure Assert.AreNotEqual(const expected, actual: Double; const message: string);
var
  tolerance : double;
begin
  tolerance := 0;
  Assert.AreNotEqual(expected,actual,tolerance,message);
end;

class procedure Assert.AreNotEqual(const expected, actual, tolerance: double; const message: string);
begin
  if Math.SameValue(expected, actual, tolerance) then
    Fail(Format('%g equals actual %g %s' ,[expected,actual,message]), ReturnAddress);
end;


class procedure Assert.AreNotEqualMemory(const expected, actual: Pointer; const size: Cardinal; const message: string);
begin
  if CompareMem(expected,actual, size) then
    Fail('Memory values are equal. ' + message, ReturnAddress);
end;

class procedure Assert.AreNotSame(const expected, actual: TObject; const message: string);
begin
  if expected.Equals(actual) then
    Fail(Format('Object [%s] Equals Object [%s] %s',[expected.ToString,actual.ToString,message]), ReturnAddress);
end;

class procedure Assert.AreNotSame(const expected, actual: IInterface; const message: string);
begin
  if (expected as IInterface) = (actual as IInterface) then
    Fail(Format('references are the same. %s',[message]), ReturnAddress);
end;

class procedure Assert.AreSame(const expected, actual: IInterface; const message: string);
begin
  if (expected as IInterface) <> (actual as IInterface) then
    Fail(Format('references are Not the same. %s',[message]), ReturnAddress);
end;

class procedure Assert.AreSame(const expected, actual: TObject; const message: string);
begin
  if not expected.Equals(actual) then
    Fail(Format('Object [%s] Not Object [%s] %s',[expected.ToString,actual.ToString,message]), ReturnAddress);
end;

{$IFDEF DELPHI_XE_UP}
//Delphi 2010 compiler bug breaks this
class procedure Assert.Contains<T>(const list: IEnumerable<T>; const value: T; const message: string);
var
  o : T;
  comparer : IComparer<T>;
begin
  comparer := TComparer<T>.Default;
  for o in list do
  begin
    if comparer.Compare(o,value) = 0 then
      exit;
  end;

  Fail(Format('List does not contain value %s. %s',[TValue.From<T>(value).ToString, message]), ReturnAddress);
end;

class procedure Assert.Contains<T>(const arr : array of T; const value : T; const message : string = '');
var
  o : T;
  comparer : IComparer<T>;
begin
  comparer := TComparer<T>.Default;
  for o in arr do
  begin
    if comparer.Compare(o,value) = 0 then
      exit;
  end;

  Fail(Format('List does not contain value %s. %s',[TValue.From<T>(value).ToString, message]), ReturnAddress);
end;

{$ENDIF}

{$IFDEF DELPHI_XE_UP}
//Delphi 2010 compiler bug breaks this
class procedure Assert.DoesNotContain<T>(const list: IEnumerable<T>; const value: T; const message: string);
var
  o : T;
  comparer : IComparer<T>;
begin
  comparer := TComparer<T>.Default;
  for o in list do
  begin
    if comparer.Compare(o,value) = 0 then
      Fail(Format('List contains value %s. %s',[TValue.From<T>(value).ToString, message]), ReturnAddress);
  end;
end;

class procedure Assert.DoesNotContain<T>(const arr : array of T; const value : T; const message : string = '');
var
  o : T;
  comparer : IComparer<T>;
begin
  comparer := TComparer<T>.Default;
  for o in arr do
  begin
    if comparer.Compare(o,value) = 0 then
      Fail(Format('List contains value %s. %s',[TValue.From<T>(value).ToString, message]), ReturnAddress);
  end;
end;
{$ENDIF}

class procedure Assert.Fail(const message : string; const errorAddrs : pointer);
begin
  //If we have been given a return then use it. (makes the exception appear on level above in the stack)
  if errorAddrs <> nil then
    raise ETestFailure.Create(message) at errorAddrs
  else
    //Otherwise use the return address we can currently get to for where to raise the exception
    raise ETestFailure.Create(message) at ReturnAddress;

end;


class procedure Assert.Pass(const message: string);
begin
  raise ETestPass.Create(message);
end;

class procedure Assert.Implements<T>(value: IInterface; const message: string);
begin
  if not Supports(value,GetTypeData(TypeInfo(T)).Guid) then
    Fail(Format('value does not implement %s. %s', [GetTypeName(TypeInfo(T)), message]),ReturnAddress);
end;

class procedure Assert.InheritsFrom(const descendant, parent: TClass; const message: string);
var
  msg : string;

begin
  if (descendant = nil) or (parent = nil) or (not descendant.InheritsFrom(parent)) then
  begin
    msg := ' does not inherit from ';
    if descendant = nil then
      msg := 'nil' + msg
    else
      msg := descendant.ClassName + msg;
    if parent = nil then
      msg := msg + 'nil'
    else
      msg := parent.ClassName + msg;
    msg := msg + '.';
    if True then
    if message <> '' then
      msg := msg + ' ' + message;

    Fail(msg, ReturnAddress);
  end;

end;

class procedure Assert.IsEmpty(const value: IInterfaceList; const message: string);
begin
  if value.Count > 0 then
    Fail(Format('List is Not empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsEmpty(const value: TList; const message: string);
begin
  if value.Count > 0 then
    Fail(Format('List is Not empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsEmpty(const value, message: string);
begin
  if Length(value) > 0 then
    Fail(Format('String is Not empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsEmpty(const value: Variant; const message: string);
begin
  if VarIsEmpty(value) or VarIsNull(value) then
    Fail(Format('Variant is Not empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsEmpty(const value: TStrings; const message: string);
begin
  if value.Count > 0 then
    Fail(Format('List is Not empty. %s',[message]), ReturnAddress);
end;

{$IFDEF DELPHI_XE_UP}
//Delphi 2010 compiler bug breaks this
class procedure Assert.IsEmpty<T>(const value: IEnumerable<T>; const message: string);
var
  o : T;
  count : integer;
begin
  count := 0;
  for o in value do
    Inc(count);

  if count > 0 then
    Fail(Format('List is Not empty. %s',[message]), ReturnAddress);
end;
{$ENDIF}

class procedure Assert.IsFalse(const condition: boolean; const message: string);
begin
  if condition then
   Fail(Format('Condition is True when False expected. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotEmpty(const value: TList; const message: string);
begin
  if value.Count = 0 then
   Fail(Format('List is Empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotEmpty(const value: IInterfaceList; const message: string);
begin
  if value.Count = 0 then
   Fail(Format('List is Empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotEmpty(const value: TStrings; const message: string);
begin
  if value.Count = 0 then
   Fail(Format('List is Empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotEmpty(const value, message: string);
begin
  if value = '' then
   Fail(Format('Variant is Empty. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotEmpty(const value: Variant; const message: string);
begin
  if VarIsEmpty(value) then
    Fail(Format('Variant is Empty. %s',[message]), ReturnAddress);
end;

{$IFDEF DELPHI_XE_UP}
//Delphi 2010 compiler bug breaks this
class procedure Assert.IsNotEmpty<T>(const value: IEnumerable<T>; const message: string);
var
  x : T;
  count : integer;
begin
  count := 0;
  for x in value do
    Inc(count);

  if count = 0 then
    Fail(Format('List is Empty when Not empty expected. %s',[message]), ReturnAddress);
end;
{$ENDIF}

class procedure Assert.IsNotNull(const condition: IInterface; const message: string);
begin
  if condition = nil then
    Fail(Format('Interface is Nil when not nil expected. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotNull(const condition: Pointer; const message: string);
begin
  if condition = nil then
    Fail(Format('Pointer is Nil when not Nil expected. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotNull(const condition: TObject; const message: string);
begin
  if condition = nil then
    Fail(Format('Object is Nil when Not Nil expected. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNotNull(const condition: Variant; const message: string);
begin
  if VarIsNull(condition) then
    Fail(Format('Variant is Null when Not Null expcted. %s',[message]), ReturnAddress);
end;

class procedure Assert.IsNull(const condition: Variant; const message: string);
begin
  if not VarIsNull(condition) then
    Fail(Format('Variant is Not Null when Null expected. [%s]',[message]), ReturnAddress);
end;

class procedure Assert.IsNull(const condition: IInterface; const message: string);
begin
  if condition <> nil then
    Fail(Format('Interface is not Nil when nil expected. [%s]',[message]), ReturnAddress);
end;

class procedure Assert.IsNull(const condition: TObject; const message: string);
begin
  if condition <> nil then
    Fail(Format('Object is not nil when nil expected. [%s]',[message]), ReturnAddress);
end;

class procedure Assert.IsNull(const condition: Pointer; const message: string);
begin
  if condition <> nil then
    Fail(Format('Pointer is not Nil when nil expected. [%s]',[message]), ReturnAddress);
end;

class procedure Assert.IsTrue(const condition: boolean;const message : string);
begin
  if not condition then
    Fail(Format('Condition is False when True expected. [%s]',[message]), ReturnAddress);
end;

{$IFDEF DELPHI_XE_UP}
//Delphi 2010 compiler bug breaks this
class procedure Assert.IsType<T>(const value: T; const message : string);
var
  val : TValue;
begin
  begin
    val := TValue.From<T>(value);
    if not val.IsType<T> then
      Fail('value is not of type T', ReturnAddress);
  end;
end;
{$ENDIF}

class procedure Assert.WillNotRaise(const AMethod: TTestMethod; const exceptionClass: ExceptClass; const msg: string);
begin
  Assert.WillNotRaise(
    procedure
    begin
      AMethod;
    end,
    exceptionClass, msg);
end;

class procedure Assert.WillNotRaiseAny(const AMethod: TTestLocalMethod;  const msg: string);
begin
  try
    AMethod;
  except
    on e : TObject do // For those who throw exceptions not descending from Exception.
    begin
      if e is Exception  then
      begin
        Fail(Format('Method raised [%s] was expecting not to raise Any exception. %s', [e.ClassName, exception(e).message]), ReturnAddress);
      end
      else
        Fail(Format('Method raised [%s] was expecting not to raise Any exception.', [e.ClassName]), ReturnAddress);
    end;
  end;
end;

class procedure Assert.WillNotRaiseAny(const AMethod: TTestMethod;const msg: string);
begin
  Assert.WillNotRaiseAny(
    procedure
    begin
      AMethod;
    end,
     msg);
end;

class procedure Assert.WillNotRaiseDescendant(const AMethod: TTestLocalMethod;
  const exceptionClass: ExceptClass; const msg: string);
begin
  try
    AMethod;
  except
    on e : Exception do
    begin
      if exceptionClass <> nil then
      begin
        if e is exceptionClass then
           Fail('Method raised an exception of type : ' + exceptionClass.ClassName + sLineBreak + e.Message + AddLineBreak(msg), ReturnAddress);
      end
      else
        Fail(Format('Method raised [%s] was expecting not to raise [%s]. %s', [e.ClassName, exceptionClass.ClassName, e.message]), ReturnAddress);
    end;
  end;
end;

class procedure Assert.WillNotRaiseDescendant(const AMethod: TTestMethod;
  const exceptionClass: ExceptClass; const msg: string);
begin
  Assert.WillNotRaise(
    procedure
    begin
      AMethod;
    end,
    exceptionClass, msg);
end;

class procedure Assert.WillRaise(const AMethod : TTestLocalMethod; const exceptionClass : ExceptClass; const msg : string);
begin
  try
    AMethod;
  except
    on E: Exception do
    begin
      CheckExceptionClass(e, exceptionClass);
      Exit;
    end;
  end;
  Fail('Method did not throw any exceptions.' + AddLineBreak(msg), ReturnAddress);
end;


class procedure Assert.WillNotRaise(const AMethod : TTestLocalMethod; const exceptionClass : ExceptClass; const msg : string);
begin
  try
    AMethod;
  except
    on e : Exception do
    begin
      if exceptionClass <> nil then
      begin
        if e.ClassType = exceptionClass then
           Fail('Method raised an exception of type : ' + exceptionClass.ClassName + sLineBreak + e.Message + AddLineBreak(msg), ReturnAddress)
        else
//          Fail(Format('Method raised [%s] was expecting not to raise [%s]. %s', [e.ClassName, exceptionClass.ClassName, e.message]), ReturnAddress);
      end
      else
        Fail(Format('Method raised [%s] was expecting not to raise exception. %s', [e.ClassName, e.message]), ReturnAddress);
    end;
  end;
end;

class procedure Assert.WillRaise(const AMethod: TTestMethod; const exceptionClass: ExceptClass; const msg: string);
begin
  Assert.WillRaise(
    procedure
    begin
      AMethod;
    end,
    exceptionClass, msg);
end;

class procedure Assert.WillRaiseAny(const AMethod: TTestLocalMethod;
  const msg: string);
begin
  try
    AMethod;
  except
    on E: Exception do
    begin
      Exit;
    end;
  end;
  Fail('Method did not throw any exceptions.' + AddLineBreak(msg), ReturnAddress);
end;

class procedure Assert.WillRaiseAny(const AMethod: TTestMethod;
  const msg: string);
begin
  Assert.WillRaiseAny(
    procedure
    begin
      AMethod;
    end,
       msg);
end;

class procedure Assert.WillRaiseDescendant(const AMethod: TTestLocalMethod;
  const exceptionClass: ExceptClass; const msg: string);
begin
  try
    AMethod;
  except
    on E: Exception do
    begin
      CheckExceptionClassDescendant(e, exceptionClass);
      Exit;
    end;
  end;
  Fail('Method did not throw any exceptions.' + AddLineBreak(msg), ReturnAddress);
end;

class procedure Assert.WillRaiseDescendant(const AMethod: TTestMethod;
  const exceptionClass: ExceptClass; const msg: string);
begin
  Assert.WillRaiseDescendant(
    procedure
    begin
      AMethod;
    end,
    exceptionClass, msg);
end;

class procedure Assert.WillRaiseWithMessage(const AMethod: TTestLocalMethod; const exceptionClass: ExceptClass;const exceptionMsg, msg: string);
begin
  try
    AMethod;
  except
    on E: Exception do
    begin
      CheckExceptionClass(E, exceptionClass);
      if (exceptionMsg <> '') and (not SameStr(E.Message, exceptionMsg)) then
        Fail(Format('Exception [%s] was raised with message [%s] was expecting [%s] %s', [E.ClassName, E.Message, exceptionMsg, msg]));
      Exit;
    end;
  end;
  Fail('Method did not throw any exceptions.' + AddLineBreak(msg), ReturnAddress);
end;

class procedure Assert.AreEqual(const expected : string; const actual : string; const message : string);
begin
  Assert.AreEqual(expected, actual, true, message);
end;

class procedure Assert.AreEqual(const expected, actual : string;  const ignoreCase : boolean; const message: string);
begin
  if ignoreCase then
  begin
    if not SameText(expected,actual) then
      Fail(Format('[%s] is Not Equal to [%s] %s',[expected,actual,message]), ReturnAddress);
  end
  else if not SameStr(expected,actual) then
      Fail(Format('[%s] is Not Equal to [%s] %s',[expected,actual,message]), ReturnAddress);
end;

class procedure Assert.CheckExceptionClass(E: Exception; const exceptionClass: ExceptClass);
begin
  if exceptionClass = nil then
    Exit;

  if E.ClassType <> exceptionClass then
    Fail(Format('Method raised [%s] was expecting [%s]. %s', [E.ClassName, exceptionClass.ClassName, E.message]), ReturnAddress);
end;

class procedure Assert.CheckExceptionClassDescendant(E: Exception;
  const exceptionClass: ExceptClass);
begin
  if exceptionClass = nil then
    Exit;

  if not (E is exceptionClass) then
    Fail(Format('Method raised [%s] was expecting a descendant of [%s]. %s', [E.ClassName, exceptionClass.ClassName, E.message]), ReturnAddress);
end;

class procedure Assert.Contains(const theString : string; const subString : string; const ignoreCase : boolean; const message : string);
begin
  if ignoreCase then
  begin
    if not StrUtils.ContainsText(theString,subString) then
      Fail(Format('[%s] does not contain [%s] %s',[theString,subString,message]), ReturnAddress);
  end
  else if not StrUtils.ContainsStr(theString,subString) then
    Fail(Format('[%s] does not contain [%s] %s',[theString,subString,message]), ReturnAddress);
end;

class procedure Assert.EndsWith(const theString : string; const subString : string; const ignoreCase : boolean; const message : string);
begin
  if ignoreCase then
  begin
    if not StrUtils.EndsText(theString,subString) then
      Fail(Format('[%s] does not end with [%s] %s',[theString,subString,message]), ReturnAddress);
  end
  else if not StrUtils.EndsStr(theString,subString) then
    Fail(Format('[%s] does not end with [%s] %s',[theString,subString,message]), ReturnAddress);
end;
{$IFDEF SUPPORTS_REGEX}
class procedure Assert.IsMatch(const regexPattern, theString, message: string);
begin
  if not TRegEx.IsMatch(theString,regexPattern) then
    Fail(Format('[%s] does not match [%s] %s',[theString,regexPattern,message]), ReturnAddress);
end;
{$ENDIF}

class procedure Assert.StartsWith(const theString : string; const subString : string; const ignoreCase : boolean; const message: string);
begin
  if ignoreCase then
  begin
    if not StrUtils.StartsText(theString,subString) then
      Fail(Format('[%s] does Not Start with [%s] %s',[theString,subString,message]), ReturnAddress);
  end
  else if not StrUtils.StartsStr(theString,subString) then
    Fail(Format('[%s] does Not Start with [%s] %s',[theString,subString,message]), ReturnAddress);
end;

{ Test }

constructor TestAttribute.Create;
begin
  FEnabled := True;
end;

constructor TestAttribute.Create(const AEnabled: boolean);
begin
  FEnabled := AEnabled;
end;

constructor IgnoreAttribute.Create(const AReason: string);
begin
  FReason := AReason;
end;

class procedure Assert.AreEqual(const expected, actual: boolean; const message: string);
begin
  if expected <> actual then
    Fail(Format('Expected %s but got %s %s' ,[BoolToStr(expected, true), BoolToStr(actual, true), message]), ReturnAddress);
end;

{ TDUnitXOptions }

constructor TDUnitXOptions.Create;
begin
  Run := TStringList.Create;
  LogLevel := TLogLevel.Information;
  ExitBehavior := TDUnitXExitBehavior.Pause;
end;


class function TDUnitX.CreateRunner: ITestRunner;
begin
  result := CreateRunner(nil);
end;

class function TDUnitX.CreateRunner(const ALogger: ITestLogger): ITestRunner;
begin
  result := TDUnitXTestRunner.Create(ALogger);
end;


procedure WriteLine(consoleWriter : IDUnitXConsoleWriter; const value : string);
begin
  if consoleWriter <> nil then
    consoleWriter.WriteLn(value)
  else
    System.Writeln(value);
end;


procedure ShowUsage(consoleWriter : IDUnitXConsoleWriter);
begin
  if consoleWriter <> nil then
    consoleWriter.SetColour(ccBrightYellow,ccDefault);
  Writeline(consoleWriter, Format('Usage : %s options', [ExtractFileName(ParamStr(0))])+#13#10);
  Writeline(consoleWriter, ' Options :');
  if consoleWriter <> nil then
    consoleWriter.SetColour(ccBrightWhite,ccDefault);

  TOptionsRegistry.PrintUsage(procedure(value : string)
                            begin
                               WriteLine(consoleWriter, value);
                            end);
  if consoleWriter <> nil then
    consoleWriter.SetColour(ccDefault);
end;

class procedure TDUnitX.CheckCommandLine;
var
  parseResult : ICommandLineParseResult;
  consoleWriter : IDUnitXConsoleWriter;
begin
  parseResult := TOptionsRegistry.Parse;
  if parseResult.HasErrors then
  begin
    //if it's a console tell the user what they did wrong
    if IsConsole then
    begin
      //we may have sucessfully parsed this option so we should respect it.
      if not FOptions.HideBanner then
        DUnitX.Banner.ShowBanner;

      consoleWriter := TDUnitXIoC.DefaultContainer.Resolve<IDUnitXConsoleWriter>;
      if consoleWriter <> nil then
        consoleWriter.SetColour(ccBrightRed,ccDefault);
      Writeline(consoleWriter, parseResult.ErrorText);
      //if the user said hidebanner then don't print the usage either
      if not FOptions.HideBanner then
        ShowUsage(consoleWriter);
      if consoleWriter <> nil then
        consoleWriter.SetColour(ccDefault,ccDefault);
      System.ExitCode :=EXIT_OPTIONS_ERROR;
      raise ECommandLineError.Create(parseResult.ErrorText);
    end
    else
      //Not a console app, raise an exception and let the GUI app deal with it??
      raise ECommandLineError.Create(parseResult.ErrorText);
  end
  else
  begin
    //no parse errors, so now build the filter. will throw if there is an error.
    FFilter := TDUnitXFilterBuilder.BuildFilter(FOptions);

    //Command line options parsed ok.
    if IsConsole then
    begin
      if not FOptions.HideBanner then
        DUnitX.Banner.ShowBanner;
      //if /? or -h then just show usage and exit
      if FOptions.ShowUsage then
      begin
        consoleWriter := TDUnitXIoC.DefaultContainer.Resolve<IDUnitXConsoleWriter>;
        ShowUsage(consoleWriter);
        Halt(EXIT_OK);
      end;
    end
  end;

end;

class constructor TDUnitX.Create;
begin
  FOptions := TDUnitXOptions.Create;
  RegisteredFixtures := TDictionary<TClass,string>.Create;
  RegisteredPlugins  := TList<IPlugin>.Create;
  //Make sure we have at least a dummy memory leak monitor registered.
  if not TDUnitXIoC.DefaultContainer.HasService<IMemoryLeakMonitor> then
    DUnitX.MemoryLeakMonitor.Default.RegisterDefaultProvider;
  FFilter := nil;
end;

class function TDUnitX.CurrentRunner: ITestRunner;
begin
  if not TDUnitXTestRunner.FActiveRunners.TryGetValue(TThread.CurrentThread.ThreadId,result) then
    raise Exception.Create('No Runner found for current thread');

end;

class destructor TDUnitX.Destroy;
begin
  RegisteredFixtures.Free;
  RegisteredPlugins.Free;
  FOptions.Free;
end;

class procedure TDUnitX.RegisterPlugin(const plugin: IPlugin);
begin
  if plugin = nil then
    raise Exception.Create('Nil plug registered!');
  RegisteredPlugins.Add(plugin);
end;

class procedure TDUnitX.RegisterTestFixture(const AClass: TClass; const AName : string);
var
  sName : string;
  attrib : TestFixtureAttribute;
  rType : TRttiType;
begin
  // If a name is passed in, then that's what we'll use, otherwise see if there
  // is a TestFixture attribute and if it's name is set then use it. If no
  // attribute then fallback to classname
  if AName <> '' then
    sName := AName
  else
  begin
    rType := DUnitX.Utils.GetRttiType(AClass);
    if rType <> nil then
    begin
      if rType.TryGetAttributeOfType<TestFixtureAttribute>(attrib) then
        sName := attrib.Name;
    end;


    if sName = '' then
      sName := AClass.ClassName;


  end;

  if not RegisteredFixtures.ContainsKey(AClass) then
      RegisteredFixtures.Add(AClass,sName );
end;

destructor TDUnitXOptions.Destroy;
begin
  FRun.Free;
  inherited;
end;

{ TestCaseAttribute }


constructor TestCaseAttribute.Create(const ACaseName: string; const AValues: string;const ASeperator : string);
var
  i: Integer;
  l : integer;
  lValues : TStringDynArray;
begin
  FCaseInfo.Name := ACaseName;
  lValues := SplitString(AValues,ASeperator);
  l := Length(lValues);
  SetLength(FCaseInfo.Values,l);
  for i := 0 to l -1 do
    FCaseInfo.Values[i] := TValue.From<string>(lValues[i]);
end;


{$IFDEF DELPHI_XE2_UP}

{ TTestFixtureHelper }

procedure TTestFixtureHelper.Log(const msg: string);
begin
  Self.Log(TLogLevel.Information,msg);
end;

procedure TTestFixtureHelper.Log(const logType : TLogLevel; const msg: string);
var
  runner : ITestRunner;
begin
  if TDUnitXTestRunner.FActiveRunners.TryGetValue(TThread.CurrentThread.ThreadId,runner) then
    runner.Log(logType,msg)
  else
    System.Writeln(msg);
end;

procedure TTestFixtureHelper.Status(const msg: string);
begin
  Self.Log(TLogLevel.Information,msg);
end;

procedure TTestFixtureHelper.WriteLn;
begin
  Self.Log(TLogLevel.Information,'');
end;

procedure TTestFixtureHelper.WriteLn(const msg: string);
begin
  Self.Log(TLogLevel.Information,msg);
end;
{$ENDIF}

function TestCaseAttribute.GetCaseInfo: TestCaseInfo;
begin
  result := FCaseInfo;
end;

function TestCaseAttribute.GetName: String;
begin
  result := FCaseInfo.Name;
end;

function TestCaseAttribute.GetValues: TValueArray;
begin
  result := FCaseInfo.Values;
end;

{ RepeatTestAttribute }

constructor RepeatTestAttribute.Create(const ACount: Cardinal);
begin
  FCount := ACount;
end;

{ IgnoreAttribute }

{ IgnoreMemoryLeaks }

constructor IgnoreMemoryLeaks.Create(const AIgnoreMemoryLeaks: Boolean);
begin
  inherited Create;
  FIgnoreMemoryLeaks := AIgnoreMemoryLeaks;
end;

{ CategoryAttribute }

constructor CategoryAttribute.Create(const ACategory: string);
begin
  FCategory := ACategory;
end;

initialization
  TDUnitX.RegisterPlugin(TDUnitXFixtureProviderPlugin.Create);

end.
