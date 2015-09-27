require 'nokogiri'
require_relative 'models'

def theme_file(name)
  "data/themes/#{name}.xml"
end

def themes_node_to_human
  doc = nil
  File.open('data/teachings.xml') do |file|
    doc = ArchiveDocument.new(Nokogiri::XML(file))
  end
  doc.archive.teachings.each do |teachings|
    teachings.theme.each do |theme|
      File.rename(theme_file(theme.page), theme_file(theme.page2))
    end
  end
end

def parse_xml(path)
  f = File.open(path)
  yield Nokogiri::XML(f, nil, 'utf-8')
  f.close
end

def save_xml(path, xml)
  File.open(path, "w") do |file|
    file << xml.to_xml(:encoding => 'utf-8')
  end
end

def each_file(dir)
  Dir.entries(dir).each do |p|
    next if p == '.' or p == '..'
    next if (/.un~$/ =~ p) != nil
    yield dir + '/' +  p
  end
end

def delete_elements(xml, xpath)
  xml.xpath(xpath).each do |e|
    e.previous.remove
    e.remove
  end
end

def themes_delete_sizes
  each_file('data/themes') do |path|
    parse_xml(path) do |xml|
      delete_elements(xml, '/theme/record/video_size')
      delete_elements(xml, '/theme/record/audio_size')
      save_xml(path, xml)
    end
  end
end
