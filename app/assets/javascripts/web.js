//= require jquery
//= require jquery_ujs
//= require jquery-2.2.3.min
//= require bootstrap.min
//= require dropdown
//= require yepnope
//= require banner
//= require stopExecutionOnTimeout

$().ready(function(){
  var screen_height = $(window).height() - 50;
  $('.page-banner').css("height",screen_height + 'px');
})