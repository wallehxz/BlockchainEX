module ApplicationHelper

  def model_errors(model,attribute)
    return model.errors.messages[attribute.to_sym][0] if model.errors.messages[attribute.to_sym]
  end

  def shown_time(time)
    if Time.now - time > 1.day
      time_ago_in_words time
    else
      time.strftime('%H:%M:%S')
    end
  end

end
