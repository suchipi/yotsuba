require 'typhoeus'
require 'fileutils'
require 'concurrent'

module Yotsuba

  class Download
    include Concurrent::Async

    attr_reader :status

    def initialize(options = {filename: nil, link: nil, part_links: nil, output_dir: nil })
      @filename = options[:filename]
      @link = options[:link]
      @part_links = options[:part_links]
      @output_dir = File.absolute_path(options[:output_dir]) if options[:output_dir]
      @status = "Queued"

      @output_dir ||= "."

      if @link.nil? && @part_links && @part_links.length == 1
        @link = @part_links.first
        @part_links = nil
      end
      init_mutex # Required by Concurrent::Async
    end

    def run
      @path = File.join(@output_dir, @filename) if @link
      @path = File.join(@output_dir, @filename+".zip") if @part_links
      FileUtils.mkdir_p @output_dir

      if File.exists? @path
        @status = "File exists"
        return
      end

      if @part_links
        @part_links.each do |link|
          create_request(link).run
        end
        finish_request
      elsif @link
        create_request(@link).run
        finish_request
      end
    end

    def run_async
      self.async.run
    end

    def delete
      File.delete(@path) if @path
    end

    def bytes_downloaded
      @path ? File.size(@path) : 0
    end

    private

      def create_request(link)
        @status = "Downloading..."
        @file_handle ||= File.new(@path, 'ab', 0644)

        request = Typhoeus::Request.new(link, followlocation: true)
        request.on_headers do |response|
          if response.code != 200
            @status = "Download failed, #{response.code}"
          end
        end
        request.on_body do |chunk|
          @file_handle.write(chunk)
        end
        return request
      end

      def finish_request
        @status = "Complete"
        @file_handle.close
      end

  end
end
