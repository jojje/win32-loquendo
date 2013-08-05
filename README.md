# Win32::Loquendo

Ruby interface to the Loquendo speech synthesis (text to speech / TTS) program.

This gem only runs on Microsoft Windows as it relies both on the Win32 API as 
well as the DLL files used by the Loquendo distribution. For that reason it 
has been name spaced in the win32 module to make it abundantly clear which
platform it supports.

## Prerequisites

* Must have Loquendo installed on the machine in order to use this gem.
* ruby ffi library, will be installed automatically through rubygems

## Installation

    $ gem install win32-loquendo

## Usage

Basic example showing the three types of use

    require 'win32/loquendo'

    reader = Win32::Loquendo::Reader.new()

    reader.say("Say it aloud")  # Send the text to the sound card

    reader.say("Give me the data") do |data|
      # do stuff with the string of PCM WAVE bytes
    end

    reader.write("audio.wav", "Save the spoken text to a file")

Customize how the text is spoken

    reader = Win32::Loquendo::Reader.new({
      :sample_rate => 32000,       # Pick a sample rate in Hz
      :channels    => 2,           # Stereo or mono (1 or 2 audio channels)
      :voice       => "Elizabeth"  # Specify the default voice to use
    })                             
    
    reader.say "Hi, this is Elizabeth speaking"  # Speak with the default voice.
    reader.say "and this is Simon", "Simon"      # Override the default voice
                                                 # for this utterance.

    reader.voices.each do |name|              # List installed voices that can 
      reader.say "My name is #{name}", name   # be used for speaking.
    end
      
Note that you can customize a lot on the fly regarding how Loquendo speaks, by
simply adding commands as part of the text being spoken. For example:

* Trigger whatever pre-programmed demo phrase the voice used was shipped with.

        reader.say("\\demosentence and I'm speaking through ruby win32-loquendo")
   
* Provide proper pronunciation for words using [X-SAMPA][*]

        reader.say("Hello, or in Finnish; \SAMPA=;('t_de4ve)", "Dave")

Finally you can launch speech prompts in parallel, overlapping to the degree 
you'd like by running reader instances in separate threads. This example
generates something eerily similar to Google's audio captchas, using 10 
overlapping voices.

    (0...40).to_a.shuffle.each_slice(4).map{|a| a.join(" ") }.map{|s|
      Thread.new { Win32::Loquendo::Reader.new.say(s) }
    }.each {|t|
      t.join
    }

A note of caution: Only ever interact with a reader from one and the same thread.
If used from different threads it will cause undefined behavior (errors, 
hangs, crashes), since the library interact with C-code over FFI and such 
interactions are not thread safe.

[*]: http://en.wikipedia.org/wiki/X-SAMPA   
