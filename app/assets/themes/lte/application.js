//= require jquery
//= require jquery_ujs
//= require jquery-2.2.3.min
//= require lte/js/jquery-ui.min
//= require lte/js/bootstrap.min
//= require lte/js/bootstrap-switch
//= require lte/js/raphael-min
//= require lte/js/morris.min
//= require lte/js/jquery.sparkline.min
//= require lte/js/moment.min
//= require lte/js/daterangepicker
//= require lte/js/bootstrap-datepicker
//= require lte/js/bootstrap3-wysihtml5.all.min
//= require lte/js/jquery.slimscroll.min
//= require lte/js/fastclick
//= require lte/js/settings
//= require lte/js/demo

 $.widget.bridge('uibutton', $.ui.button);

 function addFileUlr(obj,id){
  if (obj.files && obj.files[0]) {
    var reader = new FileReader();
    reader.onload = function (e) {
      $('#' + id).attr('src', e.target.result);
    }
    reader.readAsDataURL(obj.files[0]);
  }
 };

$('#start').datepicker({
  autoclose: true,
  todayHighlight: true
});

$('#end').datepicker({
  autoclose: true,
  todayHighlight: true
});