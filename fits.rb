# DAITSS Copyright (C) 2009 University of Florida
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

$:.unshift File.join(File.dirname(__FILE__), 'lib')

# describe.rb
require 'rubygems'
require 'sinatra'
require 'rjb'
require 'xml'

#load all required JAVA libraries.
FITS_HOME = "/Users/Carol/tools/fits-0.2.6"

class Fits < Sinatra::Default
  enable :logging

  set :root, File.dirname(__FILE__)

  error do
    'Encounter Error ' + env['sinatra.error'].name
  end

  before do
    # add all FITS jars
    jar_pattern = File.expand_path File.join(FITS_HOME, 'lib', '**', '*.jar')
    jars = Dir[jar_pattern]
    jars << "#{FITS_HOME}/xml/nlnz"
    # add our own java jar 
    jars << Dir[File.expand_path(File.join(File.dirname(__FILE__), 'jars', '*.jar'))]
    # load all the java jars, separated by colon
    Rjb::load jars.join(':')
    @fitsEngine = Rjb::import("shades.FitsEngine")
    @fits = @fitsEngine.new FITS_HOME
    puts @fits
  end
  
  get '/fits' do
    if params['location'].nil?
      throw :halt, [400, "require a location parameter."]
    end

    url = URI.parse(params['location'].to_s)
    case url.scheme
    when "file"
      @input = url.path
    when "http"
      resource = Net::HTTP.get_response url
      Tempfile.open("file2describe") do |io|
        io.write resource.body
        io.flush
        @input = io.path
      end
    else
      throw :halt, [400,  "invalid url location type"]
    end

    @originalName = url.path
    if (@input.nil?)
      throw :halt, [400,  "invalid url location"]
    end

    # make sure the file exist and it's a valid file
    if (File.exist?(@input) && File.file?(@input)) then
      puts @fits
      @fits.validateFile @input, "output.xml"
      headers 'Content-Type' => 'application/xml'
      io = open  "output.xml"
      doc = XML::Document.io io
      body doc.to_s
    else
      throw :halt, [404, "either #{@input} does not exist or it is not a valid file"]
    end

    response.finish
  end
end

Fits.run! if __FILE__ == $0