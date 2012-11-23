#!/usr/bin/ruby1.8 -I./lib/ -I../lib/


require 'test/unit'
require 'custodian/parser'




#
# Unit test for our parser.
#
class TestCustodianParser < Test::Unit::TestCase




  #
  # Create the test suite environment: NOP.
  #
  def setup
  end




  #
  # Destroy the test suite environment: NOP.
  #
  def teardown
  end




  #
  #  Test we can create a new parser object - specifically
  # that it throws exceptions if it is not given a filename
  # that exists.
  #
  def test_init

    #
    #  Constructor
    #
    assert_nothing_raised do
      Custodian::Parser.new()
    end
  end



  #
  #  Test the different kinds of parsing:
  #
  #  1.  By string - single line.
  #  2.  By array - with multiple lines.
  #  3.  By lines - with newlines.
  #
  def test_parsing_api

    #
    #  1.  By string.
    #
    parser = Custodian::Parser.new()

    #  1.a.  Comment lines return nil.
    result = parser.parse_line( "# this is a comment" )
    assert( result.nil? )

    #  1.b.  Adding a test will return an array of test-objects.
    result = parser.parse_line( "smtp.bytemark.co.uk must run smtp on 25 otherwise 'failure'." );
    assert( !result.nil? )
    assert( result.kind_of? Array )
    assert( result.size == 1 )


    #
    # 2.  By array.
    #
    parser = Custodian::Parser.new()
    #  2.a.  Comment lines return nil.
    tmp    = Array.new()
    tmp.push( "# This is a comment.." )
    assert( parser.parse_lines( tmp ).nil? )

    #  2.b.  Adding a test will return an array of test-objects.
    tmp = Array.new()
    tmp.push( "smtp.bytemark.co.uk must run ssh on 22 otherwise 'oops'." );
    ret = parser.parse_lines( tmp )
    assert( ret.kind_of? Array );
    assert( ret.size == 1 )

    #
    # 3.  By lines
    #
    parser = Custodian::Parser.new()
    #  3.a.  Comment lines return nil.
    str =<<EOF
# This is a comment
# This is also a fine comment
EOF
    assert( parser.parse_lines( str ).nil? )

    #  3.b.  Adding a test will return an array of test-objects.
    str = <<EOF
smtp.bytemark.co.uk must run smtp on 25.
google.com must run ping otherwise 'internet broken?'.
EOF
    ret = parser.parse_lines( str )
    assert( ret.kind_of? Array );
    assert( ret.size == 1 )

  end




  #
  #  Test that we can define macros.
  #
  def test_macros_lines

    parser = Custodian::Parser.new()

    #
    #  Input text
    #
    text =<<EOF
FOO is  kvm1.vm.bytemark.co.uk.
TEST is kvm2.vm.bytemark.co.uk.
EOF

    #
    # Test the parser with this text
    #
    parser.parse_lines( text )


    #
    #  We should now have two macros.
    #
    macros = parser.macros
    assert( ! macros.empty? )
    assert( macros.size() == 2 )
  end




  #
  #  Test that we can define macros.
  #
  def test_macros_array

    parser = Custodian::Parser.new()

    #
    #  Input text
    #
    text = Array.new()
    text.push( "FOO  is  kvm1.vm.bytemark.co.uk." );
    text.push( "FOO2 is  kvm2.vm.bytemark.co.uk." );

    #
    # Test the parser with this text
    #
    parser.parse_lines( text )


    #
    #  We should now have two macros.
    #
    macros = parser.macros
    assert( ! macros.empty? )
    assert( macros.size() == 2 )
  end




  #
  # Duplicate macros are a bug
  #
  def test_duplicate_macros

    parser = Custodian::Parser.new()

    #
    #  Input text to parse.
    #
    text = Array.new()
    text.push( "FOO is kvm1.vm.bytemark.co.uk." );
    text.push( "FOO is kvm2.vm.bytemark.co.uk." );

    #
    # Test the parser with this text
    #
    assert_raise ArgumentError do
      parser.parse_lines( text )
    end


    #
    #  We should now have one macro.
    #
    macros = parser.macros
    assert( ! macros.empty? )
    assert( macros.size() == 1 )
  end


end