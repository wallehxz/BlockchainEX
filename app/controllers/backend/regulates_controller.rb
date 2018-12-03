class Backend::RegulatesController < Backend::BaseController

  def index
    @regulates = Regulate.paginate(page:params[:page])
  end

  def new
  end

  def create
    @regulate = Regulate.new(regulate_params)
    if @regulate.save
      redirect_to backend_regulates_path, notice: '添加行情监管'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @regulate.update(regulate_params)
      redirect_to backend_regulates_path, notice: '更新行情监管'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @regulate.destroy
    flash[:notice] = "删除行情监管"
    redirect_to :back
  end

private

  def regulate_params
    params.require(:regulate).permit(:market_id, :amplitude, :retain, :cost, :notify_wx, :notify_sms, :notify_dd)
  end

end
