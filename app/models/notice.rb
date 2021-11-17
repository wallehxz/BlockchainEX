class Notice
  class << self

    def sms_yunpian(mobile,content = '内容')
      yunpian = 'https://sms.yunpian.com/v2/sms/tpl_single_send.json'
      params = {}
      params[:apikey] = Settings.yunpian_key
      params[:tpl_id] = Settings.yunpian_tpl
      params[:mobile] = mobile
      params[:tpl_value] = URI::escape('#report#') + '='+ URI::escape(content)
      Faraday.send(:post,yunpian, params)
    end

    def sms_batch(mobiles,content = '内容')
      mobiles.map {|mobile| sms_yunpian(mobile,content) }
    end

    def sms(content = '内容')
      sms_yunpian(Settings.default_mobile,content)
    end

    def dingding(content = '内容')
      push_url = "https://oapi.dingtalk.com/robot/send?access_token=#{Settings.dingding_bot}"
      body_params ={ msgtype:'text', text:{ content: content } }
      res = Faraday.post do |req|
        req.url push_url
        req.headers['Content-Type'] = 'application/json'
        req.body = body_params.to_json
      end
    end

    def exception(ex, mark = "application")
      path = Rails.root.to_s
      log = ex.backtrace.select { |l| l.include? path }.map {|l| l.gsub(path,'')}.join("\n")
      push_url = "https://oapi.dingtalk.com/robot/send?access_token=#{Settings.dingding_bot}"
      content =
        "#{mark}\n\n" +
        "> 类型： #{ex.message}\n" +
        "> 时间： #{Time.now.to_s(:short)}\n" +
        "> 日志： \n#{log}"
        dingding(content)
    end

  end
end