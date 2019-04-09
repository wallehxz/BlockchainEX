class Backend::MessagesController < Backend::BaseController
  def index
    @messages = Message.recent.paginate(page:params[:page])
  end

  def destroy
    @message.destroy
    flash[:notice] = "消息删除成功"
    redirect_to :back
  end
end