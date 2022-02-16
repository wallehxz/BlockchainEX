class Ticker
  class << self
      def start
        Market.seq.each do |item|
          item.generate_quote rescue nil
          item.extreme_report rescue nil
          item.volume_report rescue nil
        end
      end
  end
end