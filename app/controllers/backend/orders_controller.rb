class Backend::OrdersController < Backend::BaseController
  def index
    @orders = Order.recent
    @orders = @orders.where(type: params[:type])if params[:type].present?
    @orders = @orders.where(category: params[:cate])if params[:cate].present?
    @orders = @orders.where(state: params[:state])if params[:state].present?
    if params[:actions] == 'destroy'
      @orders.destroy_all
      flash[:warn] = "已清空所有条件数据！"
      return redirect_to :back
    end
    @orders = @orders.paginate(page:params[:page])
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
    if @order.update(order_side_params)
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
    params.require(:order).permit(:market_id, :type, :price, :amount, :category)
  end

  def order_side_params
    ['order_bid', 'order_ask'].each do |order_side|
      return params.require(order_side.to_sym).permit(:market_id, :category, :type, :price, :amount, :total, :state, :cause) if params[order_side.to_sym]
    end
  end

end
