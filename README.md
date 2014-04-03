# TivoHME

This gem provides a Ruby SDK for authoring and running Tivo Home Media Engine applications.

The Application class heirarchy was ported from the excellent [hmeforpython library (v0.20) by William McBrine](https://github.com/wmcbrine/tivohmeforpython/tree/93784b33ec2a1b199e271c9b4de3bd176da5e7f7)

Preserving the licensing from hmeforpython, everything is released under the LGPL 2.1+, except where noted. (Most of the examples are Common Public License.)

## Installation

Add this line to your application's Gemfile:

    gem 'tivohme'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tivohme

## Usage

On Linux, Mac OS X, you can start a server with all the sample apps with:

    tivohme --samples

The default port is 9142 (NOT TiVo's default of 7288 nor hmepythons default of 9042). To see more options,  run

    tivohme --help


See also the [hmeforpython README](https://github.com/wmcbrine/hmeforpython/blob/master/README.txt)

To write your own applications, use one of the examples as a starting point, then you can run it with:

    tivohme --app path/to/app.rb

## Contributing

1. Fork it ( http://github.com/<my-github-username>/tivohme/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
