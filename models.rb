require_relative 'xmldsl'
require 'date'

class TeachingsDocument < XDSL::Element
  element :title
  element :year
  elements :theme do
    element :title
    element :buddha_node
    elements :record do
      element :description
      element :record_date, Date
      element :audio_url
      element :audio_size
      element :video_url
      element :video_size
      element :youtube_id
    end
  end

  def begin_date
    t = theme.min { |a, b| a.begin_date <=> b.begin_date }
    t.begin_date
  end

  class Theme
    def begin_date
      r = record.min { |a, b| a.record_date <=> b.record_date }
      r.record_date
    end
  end
end

class BookDocument < XDSL::Element
  element :title
  elements :author
  elements :translator
  element :year
  element :isbn
  element :publisher
  element :amount
  element :annotation
  element :contents
  element :added
  element :outer_id
end

class BookCategoryDocument < XDSL::Element
  element :name
  elements :subcategory
  elements :group do
    element :name
    elements :book
  end
end

class LibraryDocument < XDSL::Element
  elements :section do
    element :name
    elements :category
  end
  element :recent do
    elements :book
  end
end

class Week
  include Comparable

  def initialize(date = Date.today)
    @monday = date - (date.cwday - 1)
  end

  def monday
    @monday
  end

  def sunday
    @monday + 6
  end

  def day(cwday)
    @monday + (cwday - 1)
  end

  def self.cwdays
    1..7
  end

  def dates
    monday..sunday
  end

  def next
    Week.new(@monday + 7)
  end

  def succ
    self.next
  end

  def <=>(week)
    self.monday <=> week.monday
  end

  def -(week)
    (@monday - week.monday).numerator / 7
  end

  def +(num)
    Week.new(@monday + 7 * num)
  end
end

class TimetableDocument < XDSL::Element

  class ClassesSingleTime
    include Comparable

    attr_reader :hour, :minute

    def initialize(hour, minute)
      @hour = hour
      @minute = minute
    end

    def to_s
      "%02d:%02d" % [ @hour, @minute ]
    end

    def self.parse(value)
      d = DateTime.parse(value)
      new(d.hour, d.minute)
    end

    def self.from_datetime(t)
      new(t.hour, t.minute)
    end

    def <=>(time)
      to_minutes <=> time.to_minutes
    end

    def to_minutes
      @hour * 24 + @minute
    end
  end

  class EventTime
    attr_reader :begin, :end

    def initialize(b, e)
      @begin = b
      @end = e
    end

    def cross(t)
      not (t.begin > @end or t.end < @begin)
    end

    def classes_time
      ClassesTime.new(ClassesSingleTime.from_datetime(@begin),
                      ClassesSingleTime.from_datetime(@end))
    end
  end

  class ClassesTime
    REGEXP = /\d{2}:\d{2}/
    DayBegin = ClassesSingleTime.new(0, 0)
    DayEnd = ClassesSingleTime.new(0, 0)

    attr_reader :begin, :end, :temp

    def initialize(b, e, temp = false)
      @begin = b
      @end = e
      @temp = temp
    end

    def self.parse(value)
      # parse *
      value.strip!
      temp = value.end_with?('*')
      value.chop! if temp

      a = value.strip.split('-')
      bs = a.shift
      return nil if not REGEXP.match(bs)
      b = ClassesSingleTime.parse(bs)
      es = a.shift
      if es
        return nil if not REGEXP.match(es)
        e = ClassesSingleTime.parse(es)
      else
        e = ClassesSingleTime.new((b.hour + 2) % 24, b.minute)
      end
      new(b, e, temp)
    end

    def to_s
      "#{@begin} - #{@end}"
    end

    def event_time(date)
      d = date
      d = date + 1 if @end <= @begin
      b = DateTime.new(date.year, date.month, date.day,
                       @begin.hour, @begin.minute)
      e = DateTime.new(d.year, d.month, d.day,
                       @end.hour, @end.minute)
      EventTime.new(b, e)
    end

    WholeDay = new(DayBegin, DayEnd)
  end

  module ParseHelper
    def parse_times(a)
      times = []
      while a.first
        time = ClassesTime.parse(a.first)
        break if time.nil?
        times << time
        a.shift
      end
      times
    end

    def parse_place(a)
      place = a.shift || 'Спартаковская'
      if not ['Спартаковская', 'Мытная'].include?(place)
        raise "address must be Спартаковская either or Мытная"
      end
      place
    end

    def parse_check_tail(a)
      raise "unparsed tail" if not a.empty?
    end
  end

  class ClassesDay
    extend ParseHelper

    attr_reader :day, :place

    def initialize(day, times, place)
      @day = day
      @times = times
      @place = place
    end

    def self.parse(value)
      a = value.split(',')

      day = Date.parse(a.shift.strip).cwday

      times = parse_times(a)
      raise "Time must be specified" if times.empty?

      place = parse_place(a)
      parse_check_tail(a)

      new(day, times, place)
    end

    def dates(b, e)
      wb = Week.new(b)
      we = Week.new(e)
      dates = (wb..we).collect do |w|
        ClassesDate.new(w.day(@day), @times, @place)
      end
      dates.select { |d| d.date >= b and d.date <= e }
    end
  end

  class ClassesDate
    extend ParseHelper

    attr_reader :date, :times, :place

    def initialize(date, times, place)
      @date = date
      @times = times
      @place = place
    end

    def self.parse(value)
      a = value.split(',')

      date = Date.parse(a.shift.strip)

      times = parse_times(a)
      place = parse_place(a)
      parse_check_tail(a)

      new(date, times, place)
    end

    def to_event
      @times.collect do |t|
        {
          time: t.event_time(@date),
          place: @place,
          temp: t.temp,
        }
      end
    end
  end

  class Cancel
    extend ParseHelper

    attr_reader :date, :times

    def initialize(date, times)
      @times = times.collect { |t| t.event_time(date) }
      @times << ClassesTime::WholeDay.event_time(date) if @times.empty?
    end

    def self.parse(value)
      a = value.split(',')

      date = Date.parse(a.shift.strip)
      times = parse_times(a)
      parse_check_tail(a)

      new(date, times)
    end

    def affect?(e)
      @times.any? { |t| t.cross(e) }
    end
  end


  element :banner do
    element :begin, Date
    element :end, Date
    element :message
  end
  element :annual
  elements :classes do
    element :image
    element :title
    element :info
    element :timeshort
    elements :day, ClassesDay
    element :begin, Date
    element :end, Date
    elements :cancel, Cancel
    elements :date, ClassesDate
    elements :changes do
      element :announce
      element :begin, Date
      element :end, Date
      elements :day, ClassesDay
      elements :date, ClassesDate
    end
  end

  elements :event do
    element :title
    element :date, ClassesDate
  end

  module DayDates
    def begin_full
      self.begin || date.map { |d| d.date }.min
    end

    def end_full
      self.end || date.map { |d| d.date }.max
    end

    def day_dates(b, e)
      r = days_range(b, e)
      day.collect { |d| d.dates(r.begin, r.end) }.flatten
    end

    def days_range(b, e)
      cb = self.begin
      ce = self.end
      b = cb if cb and cb > b
      e = ce if ce and ce < e
      b..e
    end

    def include_date?(d)
      date.any? { |cd| cd.date == d }
    end
  end

  class Classes
    include DayDates

    class Changes
      include DayDates

      def actual?
        (Week.new.next >= Week.new(begin_full)) and
          (self.end_full.nil? or Week.new <= Week.new(end_full))
      end
    end

    def future?
      b = begin_full
      b and Week.new < Week.new(b)
    end

    def past?
      e = end_full
      e and Week.new > Week.new(e)
    end

    def actual?
      not (past? or future?)
    end

    def events(b, e)
      dates = date.select { |d| d.date >= b and d.date <= e }
      dates += day_dates(b, e)

      changes.each do |c|
        if not c.day.empty?
          r = c.days_range(b, e)
          dates = dates.select { |d| d.date < r.begin or d.date > r.end }
          dates += c.day_dates(r.begin, r.end)
        end
        dates = dates.select { |d| not c.include_date?(d.date) }
        dates += c.date.select { |d| d.date >= b and d.date <= e }
      end

      events = dates.collect { |d| d.to_event }.flatten

      events.each do |e|
        e[:title] = title
        e[:cancel] = cancel.any? { |c| c.affect?(e[:time]) }
      end
    end

    def announces
      changes.select { |c| c.actual? }.collect { |c| c.announce }.join(' ')
    end
  end

  class Event
    def events(b, e)
      return [] if date.date < b or date.date > e
      events = date.to_event
      events.each { |e| e[:title] = title }
    end
  end

  class Banner
    def active?
      today = Date.today
      (self.begin.nil? or self.begin <= today - 1) and
      (self.end.nil? or today <= self.end)
    end
  end

  def events(b, e)
    r = classes.collect { |c| c.events(b, e) }.flatten
    r += event.collect { |ev| ev.events(b, e) }.flatten
    r.sort { |a, b| a[:time].begin <=> b[:time].begin }
  end
end

class MenuDocument < XDSL::Element
  elements :item do
    element :name
    element :title
    element :link
    elements :subitem do
      element :title
      element :link
    end
  end

  def about
    item.select { |i| i.name == 'about' }.first
  end

  def others
    item.select { |i| i.name != 'about' }
  end
end

class QuotesDocument < XDSL::Element
  elements :begin, Date
  elements :quote

  def current_quotes
    num = 5
    w = Week.new
    b = self.begin.select { |b| b <= w.monday }.last

    wb = Week.new(b)
    wb += 1 if not b.monday?
    (quote + quote.slice(0, num)).slice((w - wb) % quote.length, num)
  end
end
