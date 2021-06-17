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
  scope :demas, -> { where("name LIKE 'DEMA%'") }

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
    macds_a = market.indicators.macds.last(3)
    if macds_a.size > 2
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

  def dema
    if name.include? 'DEMA'
      name.split('=').last.split('|')[0].to_f
    end
  end

  def dema_up?
    demas_a = market.indicators.demas.last(4)
    if demas_a.size > 3
      demas = demas_a.map(&:dema)
      if demas.max == demas[-1]
        return true
      end
    end
    false
  end

  def dema_down?
    demas_a = market.indicators.demas.last(2)
    if demas_a.size > 1
      demas = demas_a.map(&:dema)
      if demas.min == demas[-1]
        return true
      end
    end
    false
  end

  after_create :dema_change

  def dema_change
    if name.include? 'DEMA' && dema_up? && macd_s_up?
      market.step_chasedown("移动均线DEMA上涨区间")
    end

    if name.include? 'DEMA' && dema_down?
      market.step_takeprofit("移动均线DEMA下跌区间")
    end
  end

  after_create :macd_change

  def macd_change
    if name.include? 'MACD'
      if macd_s_down? || (macd_m < 0 && macd_h_down?)
        market.step_stoploss('MACD指标直方数值 Hist Signal下跌')
      end

      if macd_s_up? && macd_h_up?
        market.step_chasedown('MACD指标Signal指标上涨')
      end
    end
  end

end
