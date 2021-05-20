function drawPrice(data, decimal) {
  var valueDecimals = decimal;
  $('#price-chart').highcharts({
    chart: { backgroundColor: null, height: 500 },
    tooltip: {backgroundColor: "#e2e2e2", borderColor: '#fff', style: {"color": "#2f2f2f"}},
    title: {text: 'Price' },
    credits: {enabled: false},
    exporting: {enabled: false},
    navigator: {enabled: false},
    legend: {enabled: false},
    xAxis: {
        type: 'datetime',
        gridLineWidth: 1,
        gridLineColor: '#fff',
        labels: {style: {color: '#9aa2a9', fill: '#9aa2a9'}}
    },
    yAxis: {
        title: {text: ''},
        gridLineWidth: 1,
        gridLineColor: '#fff',
        labels:{ formatter: function(){ return ''; } }
    },
    series: [{
        name: 'Price',
        data: data,
        type: 'spline',
        color: '#3c4ba6',
        lineWidth: 2,
        tooltip: { valueDecimals: valueDecimals },
        marker: { enabled: false },
        states: { hover: { lineWidth: 2 } }
    }]
  });
}

function drawVolume(v_data, d_data) {
  var valueDecimals = 0;
  $('#volume-chart').highcharts({
    chart: { backgroundColor: null, height: 300 },
    tooltip: { backgroundColor: "#e2e2e2", borderColor: '#fff', style: {"color": "#2f2f2f"} },
    title: {text: 'Volumes' },
    credits: {enabled: false},
    exporting: {enabled: false},
    navigator: {enabled: false},
    legend: {enabled: false},
    xAxis: {
        type: 'datetime',
        labels:{ formatter: function(){ return ''; } },
        gridLineWidth: 1,
        gridLineColor: '#fff',
        categories: d_data,
    },
    yAxis: {
        title: { text: '' },
        labels:{ formatter: function(){ return ''; } },
        gridLineWidth: 1,
        gridLineColor: '#fff',
        labels:{ formatter: function(){ return ''; } },
    },
    series: [{
        type: 'column',
        name: 'Volumes',
        color: '#ef1071',
        data: v_data,
        lineWidth: 2,
    }]
  });
}

function drawMacd(diff_data,dea_data,bar_data,date_data) {
    $('#macd-chart').highcharts({
        chart: {backgroundColor: null},
        credits: {enabled: false},
        legend: {enabled: false},
        exporting: {enabled: false},
        navigator: {enabled: false},
        title: { text: 'MACD Chart'},
        xAxis: {
            type: 'datetime',
            labels:{
                formatter: function(){
                    return '';
                    // var date = new Date(this.value);
                    // return date.getMonth() + "-" + date.getDate();
                }
            },
            style: {color: '#9aa2a9', fill: '#9aa2a9'},
            gridLineWidth: 1,
            gridLineColor: '#fff',
            categories: date_data
        },
        yAxis: {
            title: {text: ''},
            gridLineWidth: 1,
            gridLineColor: '#fff',
            labels: {
                style: {color: '#9aa2a9', fill: '#9aa2a9'},
                formatter: function() {
                    if (this.value > 1 || this.value < -1 || this.value == 0) {
                        return BigNumber(this.value).round(2, BigNumber.ROUND_DOWN).toF(2);
                    } else if (this.value < 1 || this.value > -1) {
                        return BigNumber(this.value * 100).round(4, BigNumber.ROUND_DOWN).toF(4);
                    }
                }
            }
        },
        series: [{
            name: 'DIFF',
            data: diff_data,
            type: 'spline',
            color: '#FB966E',
            lineWidth: 1,
            marker: {enabled: false},
            zIndex: 200,
            states: {hover: {lineWidth: 1}}
        },{
            name: 'DEA',
            data: dea_data,
            type: 'spline',
            color: '#AB3B3A',
            lineWidth: 1,
            marker: {enabled: false},
            zIndex: 100,
            states: {hover: {lineWidth: 1}}
        },{
            type: 'column',
            name: 'BAR',
            color: '#67C299',
            data: bar_data,
            zIndex: 10
        }]
    });
}
