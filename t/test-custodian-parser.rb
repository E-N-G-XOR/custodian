#!/usr/bin/ruby -I./lib/ -I../lib/


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
      Custodian::Parser.new
    end
  end


  def test_period
    parser = Custodian::Parser.new
    result = parser.parse_line( 'example.vm.bytemark.co.uk must run ping except between 00-23' )
    assert( result.nil? )
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
    parser = Custodian::Parser.new

    #  1.a.  Comment lines return nil.
    result = parser.parse_line( '# this is a comment' )
    assert( result.nil? )

    #  1.b.  Non-strings are an error
    assert_raise ArgumentError do
      result = parser.parse_line( nil )
    end


    #  1.c.  Adding a test will return an array of test-objects.
    result = parser.parse_line( "smtp.bytemark.co.uk must run smtp on 25 otherwise 'failure'." )
    assert( !result.nil? )
    assert( result.kind_of? Array )
    assert( result.size == 1 )


    #
    # 2.  By array.
    #
    parser = Custodian::Parser.new
    #  2.a.  Comment lines return nil.
    tmp    = []
    tmp.push( '# This is a comment..' )
    assert( parser.parse_lines( tmp ).nil? )

    #  2.b.  Adding a test will return an array of test-objects.
    tmp = []
    tmp.push( "smtp.bytemark.co.uk must run ssh on 22 otherwise 'oops'." )
    ret = parser.parse_lines( tmp )
    assert( ret.kind_of? Array )
    assert( ret.size == 1 )

    #
    # 3.  By lines
    #
    parser = Custodian::Parser.new
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
    assert( ret.kind_of? Array )
    assert( ret.size == 1 )

  end




  #
  #  Test that we can define macros.
  #
  def test_macros_lines

    parser = Custodian::Parser.new

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
    assert( macros.size == 2 )
  end




  #
  #  Test that we can define macros.
  #
  def test_macros_array

    parser = Custodian::Parser.new

    #
    #  Input text
    #
    text = []
    text.push( 'FOO  is  kvm1.vm.bytemark.co.uk.' )
    text.push( 'FOO2 is  kvm2.vm.bytemark.co.uk.' )

    #
    # Test the parser with this text
    #
    parser.parse_lines( text )


    #
    #  We should now have two macros.
    #
    macros = parser.macros
    assert( ! macros.empty? )
    assert( macros.size == 2 )
  end




  #
  # Duplicate macros are a bug
  #
  def test_duplicate_macros

    parser = Custodian::Parser.new

    #
    #  Input text to parse.
    #
    text = []
    text.push( 'FOO is kvm1.vm.bytemark.co.uk.' )
    text.push( 'FOO is kvm2.vm.bytemark.co.uk.' )

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
    assert( macros.size == 1 )
  end




  #
  # Test the expansion of macros.
  #
  def test_macro_expansion

    #
    #  Create a parser - validate it is free of macros.
    #
    parser = Custodian::Parser.new
    macros = parser.macros
    assert( macros.empty? )

    #
    #  Expand a line - which should result in no change
    # as the line does not involve a known-macro
    #
    in_txt  = 'example.bytemark.co.uk must run smtp.'
    out_txt = parser.expand_macro( in_txt )

    #
    #  The difference is the return value will be an array
    #
    assert( out_txt.kind_of? Array )
    assert( out_txt.size == 1 )
    assert( out_txt[0] == in_txt )


    #
    #  Now define a macro
    #
    parser.parse_line( 'TARGET is example1.bytemark.co.uk and example2.bytemark.co.uk.' )
    macros = parser.macros
    assert( !macros.empty? )

    #
    # Now we have a two-host macro, repeat the expansion
    #
    ret = parser.expand_macro( 'TARGET must run smtp on 25.' )

    #
    # The result should be an array
    #
    assert( ret.kind_of? Array )
    assert_equal( ret.size, 2 )
    assert( ret[0] =~ /example1/)
    assert( ret[1] =~ /example2/)

  end


  #
  # Test that the parser works for HTTP-redirection
  #
  def test_http_redirection

    #
    # test data
    #
    data = {
      'http://example must run http.'                         => true,
      'http://example must run http with status 200.'         => true,
      "http://example must run http with content 'bar'."      => true,
      'http://example must run http following redirects.'     => true,
      'http://example must run http not following redirects.' => false,
      'http://example must run http not following redirect.'  => false,
    }

    data.each do |str,follow|
      assert_nothing_raised do

        #
        # Create the new parser
        #
        obj = Custodian::TestFactory.create( str )

        assert( !obj.nil? )
        assert( obj.kind_of? Array )
        assert( obj.size == 1 )
        assert_equal( obj[0].to_s, str )

        if  follow 
          assert( obj[0].follow_redirects? )
        else
          assert( ! obj[0].follow_redirects? )
        end
      end
    end
  end



  #
  # Test that the parser works for cache-busting.
  #
  def test_http_cache_busting

    #
    # test data
    #
    data = {
      'http://example must run http.'                         => true,
      'http://example must run http with status 200.'         => true,
      "http://example must run http with content 'bar'."      => true,
      'http://example must run http without cache busting.'   => false,
    }

    data.each do |str,cb|
      assert_nothing_raised do

        #
        # Create the new parser
        #
        obj = Custodian::TestFactory.create( str )

        assert( !obj.nil? )
        assert( obj.kind_of? Array )
        assert( obj.size == 1 )
        assert_equal( obj[0].to_s, str )

        if  cb 
          assert( obj[0].cache_busting? )
        else
          assert( ! obj[0].cache_busting? )
        end
      end
    end
  end




  #
  # Test that the text we're going to use in alerters is present.
  #
  def test_alert_text

    #
    # test data
    #
    data = {
      'foo must run rsync.'                     => nil,
      'foo must run redis.'                     => nil,
      'foo must not run ping.'                  => nil,
      "foo must not run ssh otherwise 'fail'"   => 'fail',
      "foo must not run ssh otherwise 'fail'."  => 'fail',
      "foo must run redis otherwise 'memorystorage service is dead'" => 'memorystorage service is dead',
      "foo must run ping otherwise 'don't you love me?'" => 'don'
    }

    #
    #  For each test
    #
    data.each do |str,fail|
      assert_nothing_raised do

        #
        # Create the new parser
        #
        obj = Custodian::TestFactory.create( str )

        assert( !obj.nil? )
        assert( obj.kind_of? Array )
        assert( obj.size == 1 )
        assert_equal( obj[0].to_s, str )

        if  fail.nil? 
          assert( obj[0].get_notification_text.nil? )
        else
          assert_equal( obj[0].get_notification_text, fail )
        end

      end
    end
  end
end
