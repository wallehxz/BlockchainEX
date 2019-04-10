class Backend::MessagesController < Backend::BaseController
  def index
    @messages = Message.recent.paginate(page:params[:page])
  end

  def destroy
    @message.destroy
    flash[:notice] = "消息删除成功"
    redirect_to :back
  end

  def clear_history
    Message.where("created_at < ?", Time.now.beginning_of_day).destroy_all
    flash[:notice] = "历史消息清理成功"
    redirect_to :back
  end
end