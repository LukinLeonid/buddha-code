module TeachingsHelper
  def load_teachings(options = {})
    teachings = []
    each_file("#{SiteData}/teachings", options) do |path|
      File.open(path) do |file|
        teachings << {
          id: path_to_id(path),
          document: TeachingsDocument.load(file)
        }
      end
    end
    teachings
  end

  def record_date(record)
    record.record_date.strftime('%Y.%m.%d')
  end

  def record_description(record, index)
    d = record.description
    return d if not d.nil?
    "Лекция №#{index}"
  end
end

module CommonHelpers
  def dir_files(dir, options={})
    default_options = {
      full_path: true,
      sorted: false,
      reverse: false
    }
    options = default_options.merge(options)
    names = Dir.entries(dir).select { |name| /^\./.match(name).nil? }

    if options[:sorted]
      names.sort_by! { |name| name }
      names.reverse! if options[:reverse]
    end

    names.map do |name|
      if options[:full_path]
        dir + '/' +  name
      else
        name
      end
    end
  end

  def each_file(dir, options={})
    dir_files(dir, options).each { |p| yield p }
  end

  def format_date(date)
    date.strftime('%d/%m/%y')
  end

  def link_if(show, link, title)
    if show
      "<a href=#{link}>#{title}</a>"
    else
      "<span>#{title}</span>"
    end
  end

  def path_to_id(path)
    File.basename(path).gsub(/\.[^.]+$/, '')
  end

  def path_to_ext(path)
    path.gsub(/^[^.]+\./, '')
  end

  def yandex_money_url(target, title, sum, redirect)
    r = /[^a-zA-Z0-9*-._]/
    link = "#{SiteConfig::DOMAIN}#{redirect}"
    "https://money.yandex.ru/embed/shop.xml?"\
      "account=#{target}"\
      "&quickpay=shop&writer=seller"\
      "&targets=#{URI.escape(title, r)}"\
      "&default-sum=#{sum}&button-text=03"\
      "&successURL=#{URI.escape(link, r)}"
  end

  def slug(title)
    title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end

  def load_page(path, url)
    @url = url
    Tilt.new("data/#{path}").render(self)
  end

  def digest_url(url, base = nil, context = nil)
    full_url = url
    full_url = "#{base}#{url}" if not base.nil?
    output_url = url
    output_url = full_url if not context.nil? and context != base
    return output_url if settings.development?
    digest = Cache::Digest[full_url]
    return output_url if digest.nil?
    "#{output_url}?sha1=#{digest[:digest]}"
  end

  def digest_local_url(url)
    digest_url(url, @url, @context_url)
  end

  def slideshow(dir, url = (@url or '/'), context_url = @context_url)
    erb :'partials/slideshow',
        locals: {
          url: url,
          context_url: context_url,
          directory: dir,
        }
  end

  def local_uri(path, query_string)
    return path if query_string.empty?
    path += '?'
    path += query_string
  end
end

module NewsHelpers
  def render_news(news, cut)
    renders = {
      adoc: lambda { |doc, context| Asciidoctor.render(doc) },
      html: lambda { |doc, context| doc },
      erb:  lambda { |doc, context| Tilt::ERBTemplate.new { doc }.render(context) }
    }
    @url = "/news/#{news.id}/"
    doc = cut ? news.cut : news.body
    renders[news.ext.to_sym].call(doc, self)
  end
end

module BookHelpers
  def variable_row(name, value)
    return if value.nil?
    erb :'partials/variable_row', locals: { name: name, value: value }
  end

  def parse_annotation(text)
    return [] if text.nil?
    text.split "\n\n"
  end

  def parse_toc(text)
    TOC::Heading::parse(text.nil? ? '' : text)
  end

  def headings_div(heading)
    return if heading.children.empty?
    erb :'partials/headings', locals: { headings: heading.children }
  end

  def book_cover_url(id, size)
    digest_url("/books/#{id}/cover-#{size}.jpg")
  end

  def book_thumb(book)
    erb :'partials/book_thumb', locals: { book: book }
  end
end

module TimetableHelper
  def timetable_months()
    first = Week.new.monday
    last = Week.new.next.sunday
    if first.month == last.month
      Russian::strftime(first, "%B")
    else
      "#{Russian::strftime(first, '%B')} - #{Russian.strftime(last, '%B')}"
    end
  end

  def week_day(date, events)
    locals = { date: date,
               events: events.select { |e| e[:time].begin.to_date == date } }
    erb :'partials/week_day', locals: locals
  end
end
