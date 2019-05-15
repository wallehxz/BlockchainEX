class Backend::MessagesController < Backend::BaseController
  def index
    @messages = Message.recent.paginate(page:params[:page])
  end

  def alerts
    @alerts = Indicator.recent.paginate(page:params[:page])
  end

  def destroy
    @message.destroy
    flash[:notice] = "删除成功"
    redirect_to :back
  end

  def clear_history
    Message.where("created_at < ?", Time.now.beginning_of_day).destroy_all
    flash[:notice] = "消息删除成功"
    redirect_to :back
  end

  def clear_alerts
    Indicator.where("created_at < ?", Time.now.beginning_of_day).destroy_all
    flash[:notice] = "指标删除成功"
    redirect_to :back
  end
end