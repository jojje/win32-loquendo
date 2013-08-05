require 'ffi'
require 'win32/registry'
require 'tempfile'

module Win32
  module Loquendo

    ###
    # Reads text out loud or to file using the Loquendo TTS engine.
    class Reader

      ###
      # @param [Hash] opts options to be used as default configuration.
      # @option opts [Integer] :sample_rate (32000) in Hz.
      # @option opts [Integer] :channels (2) denotes Stereo or mono, 2 or 1 channel.
      # @option opts [String]  :voice (Elisabeth) default voice to use unless
      #                              overridden when calling {#say} or {#write}.
      def initialize(opts={})
        @opts = {
          :sample_rate => 32000,
          :channels    => 2,
          :voice       => "Elizabeth"
        }.merge(opts)
        @speaking = false

        # Sanity checking of input parameters
        unless @opts[:sample_rate].kind_of?(Integer) && @opts[:sample_rate] > 0
          raise LoquendoException, ":sample_rate must be an integer and larger than zero, but %s was specified" % @opts[:sample_rate].to_s
        end
        unless [1,2].include?( @opts[:channels] )
          raise LoquendoException, "audio :channels must be either 1 or 2, but %s was specified" % @opts[:channels].to_s
        end

        # Instantiate the TTS reader
        ptr = FFI::MemoryPointer.new :pointer

        unless LoqTTS7.ttsNewReader(ptr,nil) == 0
          LoqTTS7.ttsDeleteSession(nil)
          raise LoquendoException, "Failed to create TTS reader"
        end
        @reader_ptr = ptr.read_pointer
        @reader_ptr.freeze

        # Register a callback for speaking so we know when speeches end, since
        # we're interacting with the TTS engine asynchronously in order to avoid
        # blocking the entire main thread while speaking is going on.
        @callback = FFI::Function.new(:void, [:uint, :int, :pointer, :pointer]) do |speech_id, event, *ignore|
          if event == 1
            @speaking = false
            info "End of speech ##{speech_id}"
          end
        end

        unless LoqTTS7.ttsSetCallback(@reader_ptr, @callback, nil, 0) == 0
          raise LoquendoException, "Failed to register TTS reading callback"
        end

      end # init

      ###
      # Writes +text+ spoken with +voice+ to +filename+.
      # @param [String] filename to write the PCM WAV data to.
      # @param [String,#read] text to be rendered to audio.
      # @param [String] voice defaults to whatever voice was
      #   specified during the creation of the Reader object.
      def write(filename, text, voice = @opts[:voice])
        device = "LTTS7AudioFile"
        load_voice(voice)
        unless LoqTTS7.ttsSetAudio(@reader_ptr, device, filename, @opts[:sample_rate], 0, @opts[:channels], nil) == 0
          raise LoquendoException, "Failed to prepare writing audio to file via #{device} library"
        end
        render_speech(text, device)
      end

      ###
      # Speaks the provided +text+ using +voice+ through the sound card.
      # If a block is provided, the spoken WAVE-data is handed as a string of
      # bytes to the block instead of being sent to the sound card.
      # @param [String,#read] text to be spoken.
      # @param [String] voice uses whatever voice wasspecified during the
      #   creation of the Reader object unless overridden.
      def say(text, voice = @opts[:voice])
        if block_given?
          data = nil
          Dir.mktmpdir("loquendo_audio") do |dir|
            file = File.join(dir,"spoken_text.wav")
            write(file, text, voice)
            data = open(file,'rb'){|f| f.read }
          end
          yield data
        else
          say_aloud(text, voice)
        end
      end

      ###
      # @return [Array<String>] a list of the installed voices, that can be
      #                         used for speaking.
      def voices
        buff = FFI::MemoryPointer.new(:string, 1024)
        unless LoqTTS7.ttsQuery(nil, 1, "Id", nil, buff, buff.size, false, false) == 0
          raise LoquendoException, "Failed to query voices"
        end
        buff.read_string.split(";")
      end

      private #################################################################

      def say_aloud(text, voice = @opts[:voice])
        device = "LTTS7AudioBoard"
        load_voice(voice)
        unless LoqTTS7.ttsSetAudio(@reader_ptr, device, nil, @opts[:sample_rate], 0, @opts[:channels], nil) == 0
          raise LoquendoException, "Failed to prepare playing audio via #{device} library"
        end
        render_speech(text, device)
      end

      def render_speech(text, device)
        text = text.read if text.respond_to? :read
        unless LoqTTS7.ttsRead(@reader_ptr, text, true, false, 0) == 0
          raise LoquendoException, "Failed to playing audio via #{device} library"
        end
        @speaking = true  # simulate synchronous behavior without making the program
        while @speaking   # "soft-block" for the speaking duration
          sleep(0.01)
        end
      end

      def load_voice(voice)
        unless LoqTTS7.ttsLoadPersona(@reader_ptr, voice, nil, nil) == 0
          LoqTTS7.ttsDeleteSession(nil)
          raise LoquendoException, "Failed to load voice '#{voice}'"
        end
      end

      def info(msg)
        puts msg if $VERBOSE
      end

    end # Reader

    # Custom exception used for this library
    class LoquendoException < Exception
    end

    ###########################################################################
    private ###################################################################

    # Locate the installation path of the program and its DLLs
    [ [ Win32::Registry::HKEY_LOCAL_MACHINE, "SOFTWARE\\Loquendo\\LTTS7\\Engine" ],
      [ Win32::Registry::HKEY_CURRENT_USER,  "SOFTWARE\\Loquendo\\LTTS7\\Engine" ]
    ].each do |base,key|
      begin
        base.open(key) do |reg|
          DLL_PATH ||= reg['DataPath']
        end
      rescue Win32::Registry::Error
      end
    end

    raise LoquendoException, "Failed to find Loquendo TTS engine. Is the program installed?" unless defined?(DLL_PATH)

    # @private
    module LoqTTS7
      extend FFI::Library
      ffi_lib "#{DLL_PATH}bin\\LoqTTS7"
      #                                     reader      ?
      attach_function :ttsNewReader,     [ :pointer, :pointer ], :int
      #                                     reader    voice   language    ?
      attach_function :ttsLoadPersona,   [ :pointer, :string, :string, :string ], :int
      #                                     session
      attach_function :ttsDeleteSession, [ :pointer ], :int
      #                                     reader   device   filename samplr   ?    chan     ?
      attach_function :ttsSetAudio,      [ :pointer, :string, :string, :uint, :int,  :int, :pointer ], :int
      #                                     reader    text     async    ?       ?
      attach_function :ttsRead,          [ :pointer, :string, :bool,  :bool,  :ulong ], :int
      #                                      nil      1     atts     nil      resbuff  cbuff   false  false
      attach_function :ttsQuery,         [ :pointer, :int, :string, :string, :pointer, :uint,  :bool, :bool ], :int
      #                                     reader   callback     nil     0
      attach_function :ttsSetCallback,   [ :pointer, :pointer, :pointer, :int ], :int
      #
      attach_function :ttsGetErrorMessage, [ :int ], :string
      #                                     reader
      #attach_function :ttsStop,          [ :pointer ], :int  # Causes nasty hang in Ruby, probably GIL related..
    end

  end # Loquendo

end #Win32
