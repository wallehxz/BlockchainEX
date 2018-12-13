class Backend::OrdersController < Backend::BaseController
  def index
    @orders = Order.recent.paginate(page:params[:page])
  end

  def new
  end

  def create
    @order = Order.new(order_params)
    if @order.save
      redirect_to backend_orders_path, notice: '新市场订单添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @order.update(exchange_params)
      redirect_to backend_orders_path, notice: '市场订单更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @order.destroy
    flash[:success] = "市场订单删除成功"
    redirect_to :back
  end

private

  def order_params
    params.require(:order).permit(:market_id, :type, :price, :amount)
  end

end
