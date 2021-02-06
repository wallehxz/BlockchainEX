class Backend::IndicatorsController < Backend::BaseController

  def index
    @indicators = Indicator.recent.paginate(page:params[:page])
  end

  def destroy
    @indicator.destroy
    flash[:notice] = "删除成功"
    redirect_to :back
  end

  def clear_history
    Indicator.where("created_at < ?", Time.now.beginning_of_day).destroy_all
    flash[:notice] = "指标删除成功"
    redirect_to :back
  end
end