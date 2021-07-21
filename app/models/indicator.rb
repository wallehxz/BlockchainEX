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

  after_create :dmi_change

  def dmi_change
    if name.include?('MACD')
      if dmi_dd < dmi_di
        market.step_stoploss('DMI 指标 +Di 下行')
      end
    end
  end

  after_create :macd_change

  def macd_change
    if name.include?('MACD')
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
