class Backend::IndicatorsController < Backend::BaseController

  def index
    @indicators = Indicator.recent.paginate(page:params[:page])
  end

  def new
  end

  def create
    @indicator = Indicator.new(indicator_params)
    if @indicator.save
      redirect_to backend_indicators_path, notice: '新指标添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @indicator.update(indicator_params)
      redirect_to backend_indicators_path, notice: '指标更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
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

private

  def indicator_params
    params.require(:indicator).permit(:market_id, :name)
  end
end