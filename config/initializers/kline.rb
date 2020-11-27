class Array
  def tickers_to_kline
    array = []
    self.each do |item|
      if item[4].to_f - item[1].to_f > 0
        array << [item[2].to_f - item[4].to_f, item[4].to_f - item[1].to_f, item[1].to_f - item[3].to_f, item[4].to_f, item[5].to_f]
      else
        array << [item[2].to_f - item[1].to_f, item[4].to_f - item[1].to_f, item[4].to_f - item[3].to_f, item[4].to_f, item[5].to_f]
      end
    end
    array
  end

  def kline_shape
    if (self[0] + self[2]) >= 0 && self[1].abs > self[3] * 0.005
      return '高实体线'
    end
    if self[1].abs > 0 && self[0] > self[1].abs * 2 && self[2] > self[1].abs * 2
      return '长腿十字线'
    end
    if self[2] < self[3] * 0.00005 && self[1].abs > 0 &&self[0] > self[1].abs * 3
      return '射击十字星'
    end
    if self[0] < self[3] * 0.00005 && self[1].abs > 0 && self[2] > self[1].abs * 3
      return '锤头线'
    end
    if self[1].abs > 0 && self[1].abs > self[3] * 0.0025 && self[1].abs < self[3] * 0.005
      return '中实体线'
    end
    if self[1].abs > 0 && self[1].abs < self[3] * 0.0025
      return '低实体线'
    end
    return  '无特征线'
  end

  def kline_trends
    array = []
    self.each do |item|
      array << item[4].to_f - item[1].to_f
    end
    array
  end
end