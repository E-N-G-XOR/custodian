

#
# Standard modules
#
require 'beanstalk-client'
require 'logger'



#
# Implementation of our protocol tests.
#
require 'custodian/alerter.rb'
require 'custodian/protocoltest/tcp.rb'
require 'custodian/protocoltest/dns.rb'
require 'custodian/protocoltest/ftp.rb'
require 'custodian/protocoltest/http.rb'
require 'custodian/protocoltest/jabber.rb'
require 'custodian/protocoltest/ldap.rb'
require 'custodian/protocoltest/ping.rb'
require 'custodian/protocoltest/rsync.rb'
require 'custodian/protocoltest/ssh.rb'
require 'custodian/protocoltest/smtp.rb'
require 'custodian/testfactory'








#
# This class contains the code for connecting to a Beanstalk queue,
# fetching tests from it, and executing them
#
module Custodian

  class Worker


    #
    # The beanstalk queue.
    #
    attr_reader :queue

    #
    # How many times we re-test before we detect a failure
    #
    attr_reader :retry_count

    #
    # The log-file object
    #
    attr_reader :logger

    #
    # Constructor: Connect to the queue
    #
    def initialize( server, logfile )

      # Connect to the queue
      @queue = Beanstalk::Pool.new([server])

      # Instantiate the logger.
      @logger = Logger.new( logfile, "daily" )

      if ( ENV['REPEAT'] )
        @retry_count=ENV['REPEAT'].to_i
      else
        @retry_count=5
      end

    end



    #
    # Write the given message to our logfile - and show it to the console
    # if we're running with '--verbose' in play
    #
    def log_message( msg )
      @logger.info( msg )
      puts msg if ( ENV['VERBOSE'] )
    end



    #
    # Process jobs from the queue - never return.
    #
    def run!
      while( true )
        log_message( "\n" )
        log_message( "\n" )
        log_message( "Waiting for job.." )
        process_single_job()
      end
    end



    #
    # Fetch a single job from the queue, and process it.
    #
    def process_single_job

      result = false

      begin
        job = @queue.reserve()

        log_message( "Job aquired - Job ID : #{job.id}" )

        #
        #  Get the job body
        #
        body = job.body
        raise ArgumentError, "Job was empty" if (body.nil?)
        raise ArgumentError, "Job was not a string" unless body.kind_of?(String)

        #
        #  Output the job.
        #
        log_message( "Job: #{body}" )


        #
        # Did the test succeed?  If not count the number of times it failed in
        # a row.  We'll repeat several times
        #
        success = false
        count   = 0


        #
        # Create the test-object.
        #
        test = Custodian::TestFactory.create( body )


        #
        # As a result of this test we'll either raise/clear with mauve.
        #
        # This helper will do that job.
        #
        alert = Custodian::Alerter.new( test )

        #
        #  We'll run no more than MAX times.
        #
        #  We stop the execution on a single success.
        #
        while ( ( count < @retry_count ) && ( success == false ) )

          log_message( "Running test - [#{count}/#{@retry_count}]" )

          if ( test.run_test )
            log_message( "Test succeeed - clearing alert" )
            success = true
            alert.clear()
            result = true
          end
          count += 1
        end

        #
        #  If we didn't succeed on any of the attempts raise the alert.
        #
        if ( ! success )

          #
          # Raise the alert, passing the error message.
          #
          log_message( "Test failed - alerting with #{test.error()}" )
          alert.raise( test.error() )
        end

      rescue => ex
        puts "Exception raised processing job: #{ex}"

      ensure
        #
        #  Delete the job - either we received an error, in which case
        # we should remove it to avoid picking it up again, or we handled
        # it successfully so it should be removed.
        #
        log_message( "Job ID : #{job.id} - Removed" )
        job.delete if ( job )
      end

      return result
    end


    #
    #  Process jobs until we see a failure - stop then.
    #
    def process_until_fail
      while( process_single_job() )
        # nop
      end
    end

  end



end
