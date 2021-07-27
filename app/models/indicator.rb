# == Schema Information
#
# Table name: indicators
#
#  id         :integer          not null, primary key
#  market_id  :integer
#  name       :string
#  created_at :datetime
#

class Indicator < ActiveRecord::Base
  belongs_to :market
  scope :recent, -> { order('created_at desc') }
  self.per_page = 10
  scope :macds, -> { where("name LIKE 'MACD%'") }
  scope :dmis, -> { where("name LIKE 'DMI%'") }

  def value
    name.split('=')[-1].to_i
  end

  def macd_h
    if name.include? 'MACD'
      name.split('=').last.split('|')[0].to_f
    end
  end

  def macd_h_up?
    macds_a = market.indicators.macds.last(3)
    if macds_a.size > 2
      macds = macds_a.map(&:macd_h)
      if macds.max == macds[-1]
        return true
      end
    end
    false
  end

  def macd_h_down?
    macds_a = market.indicators.macds.last(3)
    if macds_a.size > 2
      macds = macds_a.map(&:macd_h)
      if macds.min == macds[-1]
        return true
      end
    end
    false
  end

  def macd_m
    if name.include? 'MACD'
      name.split('=').last.split('|')[1].to_f
    end
  end

  def macd_m_up?
    macds_a = market.indicators.macds.last(3)
    if macds_a.size > 2
      macds = macds_a.map(&:macd_m)
      if macds.max == macds[-1]
        return true
      end
    end
    false
  end

  def macd_m_down?
    macds_a = market.indicators.macds.last(2)
    if macds_a.size > 1
      macds = macds_a.map(&:macd_m)
      if macds.min == macds[-1]
        return true
      end
    end
    false
  end

  def macd_s
    if name.include? 'MACD'
      name.split('=').last.split('|')[2].to_f
    end
  end

  def macd_s_up?
    macds_a = market.indicators.macds.last(3)
    if macds_a.size > 2
      macds = macds_a.map(&:macd_s)
      if macds.max == macds[-1]
        return true
      end
    end
    false
  end

  def macd_s_down?
    macds_a = market.indicators.macds.last(2)
    if macds_a.size > 1
      macds = macds_a.map(&:macd_s)
      if macds.min == macds[-1]
        return true
      end
    end
    false
  end

  def dmi_dx
    if name.include? 'DMI'
      name.split('=').last.split('|')[0].to_f
    end
  end

  def dmi_dd
    if name.include? 'DMI'
      name.split('=').last.split('|')[1].to_f
    end
  end

  def dmi_di
    if name.include? 'DMI'
      name.split('=').last.split('|')[2].to_f
    end
  end

  after_create :binance_dmi_change
  def binance_dmi_change
    if name.include?('DMI') && market.source == 'binance'
      if dmi_dd < dmi_di
        market.step_stoploss('DMI 指标 +Di 下行')
      end
    end
  end

  after_create :future_dmi_change
  def future_dmi_change
    if name.include?('DMI') && market.source == 'future' && market.regulate.fast_trade
      dmis = market.indicators.dmis.last(5)
      diff = dmis.map {|x| x.dmi_dd - x.dmi_di}
      # 指标由下跌变为上涨 做多
      if diff[-1] > 0 && diff[-2] < 0 && diff[0..3].max < 0
        amount = market.regulate.fast_cash
        price  = market.get_price
        market.new_kai_long(price[:bid], amount)

        #如果空单有盈利 则市价平仓
        short = market.short_position
        if short['unrealizedProfit'].to_f > 0
          market.new_ping_short(price[:bid], short['positionAmt'].to_f.abs, 'market')
        end
      end

      # 指标由上涨变为下跌 做空
      if diff[-1] < 0 && diff[-2] > 0 && diff[0..3].max > 0
        amount = market.regulate.fast_cash
        price  = market.get_price
        market.new_kai_short(price[:ask], amount)

        #如果多单有盈利 则市价平仓
        long = market.long_position
        if long['unrealizedProfit'].to_f > 0
          market.new_ping_long(price[:bid], long['positionAmt'].to_f.abs, 'market')
        end
      end
    end
  end

  after_create :binance_macd_change
  def binance_macd_change
    if name.include?('MACD') && market.source == 'binance'
      if macd_s_down? && macd_h_down?
        market.step_takeprofit('Signal 下跌 Hist 下跌')
      end

      if macd_s_up? && macd_m_up?
        market.step_chasedown('Signal 上涨 MACD 上涨')
      end

      if macd_s < 0 && macd_s_down?
        market.step_stoploss('Signal 零下跌')
      end
    end
  end

end
