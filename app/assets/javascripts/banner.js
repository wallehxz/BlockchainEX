/**
 * Created by cuipengfei on 16/9/26.
 */
(function () {

    var $$ = function (selector, context) {
        var context = context || document;
        var elements = context.querySelectorAll(selector);
        return [].slice.call(elements);
    };
    function _fncSliderInit($slider, options) {
        var prefix = '.fnc-';
        var $slider = $slider;
        var $slidesCont = $slider.querySelector(prefix + 'slider__slides');
        var $slides = $$(prefix + 'slide', $slider);
        var $controls = $$(prefix + 'nav__control', $slider);
        var $dotCommonsRight = $$('.dot-commonRight', $slider);
        var $dotCommonsLift = $$('.dot-commonLift', $slider);
        var $controlsBgs = $$(prefix + 'nav__bg', $slider);
        var $progressAS = $$(prefix + 'nav__control-progress', $slider);
        var numOfSlides = $slides.length;
        var curSlide = 1;
        var sliding = false;
        var slidingAT = +parseFloat(getComputedStyle($slidesCont)['transition-duration']) * 1000;
        var slidingDelay = +parseFloat(getComputedStyle($slidesCont)['transition-delay']) * 1000;
        var autoSlidingActive = false;
        var autoSlidingTO;
        var autoSlidingDelay = 5000;
        var autoSlidingBlocked = false;
        var $activeSlide;
        var $activeControlsBg;
        var $prevControl;
        function setIDs() {
            $slides.forEach(function ($slide, index) {
                $slide.classList.add('fnc-slide-' + (index + 1));
            });
            $controls.forEach(function ($control, index) {
                $control.setAttribute('data-slide', index + 1);
                $control.classList.add('fnc-nav__control-' + (index + 1));
            });
            $controlsBgs.forEach(function ($bg, index) {
                $bg.classList.add('fnc-nav__bg-' + (index + 1));
            });
        }
        ;
        setIDs();
        function afterSlidingHandler() {
            $slider.querySelector('.m--previous-slide').classList.remove('m--active-slide', 'm--previous-slide');
            $slider.querySelector('.m--previous-nav-bg').classList.remove('m--active-nav-bg', 'm--previous-nav-bg');
            $activeSlide.classList.remove('m--before-sliding');
            $activeControlsBg.classList.remove('m--nav-bg-before');
            $prevControl.classList.remove('m--prev-control');
            $prevControl.classList.add('m--reset-progress');
            var triggerLayout = $prevControl.offsetTop;
            $prevControl.classList.remove('m--reset-progress');
            sliding = false;
            var layoutTrigger = $slider.offsetTop;
            if (autoSlidingActive && !autoSlidingBlocked) {
                setAutoslidingTO();
            }
        }
        ;
        function performSliding(slideID) {
            for(var i=0; i<$('.fnc-nav__control-progress').length;i++ ){
                $('.fnc-nav__control-progress')[i].style.width = '100%';
            }
            if (sliding)
                return;
            sliding = true;
            window.clearTimeout(autoSlidingTO);
            curSlide = slideID;
            $prevControl = $slider.querySelector('.m--active-control');
            $prevControl.classList.remove('m--active-control');
            $prevControl.classList.add('m--prev-control');
            $slider.querySelector(prefix + 'nav__control-' + slideID).classList.add('m--active-control');

            $activeSlide = $slider.querySelector(prefix + 'slide-' + slideID);
            $activeControlsBg = $slider.querySelector(prefix + 'nav__bg-' + slideID);
            $slider.querySelector('.m--active-slide').classList.add('m--previous-slide');
            $slider.querySelector('.m--active-nav-bg').classList.add('m--previous-nav-bg');
            $activeSlide.classList.add('m--before-sliding');
            $activeControlsBg.classList.add('m--nav-bg-before');
            var layoutTrigger = $activeSlide.offsetTop;
            $activeSlide.classList.add('m--active-slide');
            $activeControlsBg.classList.add('m--active-nav-bg');
            setTimeout(afterSlidingHandler, slidingAT + slidingDelay);
        }
        ;
        function controlClickHandler() {
            if (sliding)
                return;
            if (this.classList.contains('m--active-control'))
                return;
            if (options.blockASafterClick) {
                autoSlidingBlocked = true;
                $slider.classList.add('m--autosliding-blocked');
            }
            var slideID = +this.getAttribute('data-slide');
            performSliding(slideID);
        };
        function controlClickEdge() {
            if (sliding)
                return;
            if (this.classList.contains('m--active-control'))
                return;
            if (options.blockASafterClick) {
                autoSlidingBlocked = true;
                $slider.classList.add('m--autosliding-blocked');
            }
            performSliding(curSlide);
        };
        function controlClickEdge1() {
            if (sliding)
                return;
            if (this.classList.contains('m--active-control'))
                return;
            if (options.blockASafterClick) {
                autoSlidingBlocked = true;
                $slider.classList.add('m--autosliding-blocked');
            }

            var num = $('.m--active-control')[0].getAttribute('data-slide');
            if(num == 1){
                num = $('.fnc-nav__control-progress').length;
            }else{
                num = num - 1;
            }

            performSliding(num);
        };
        $controls.forEach(function ($control) {
            $control.addEventListener('click', controlClickHandler);
        });
        $dotCommonsRight.forEach(function ($common) {
            $common.addEventListener('click', controlClickEdge);
        });

        $dotCommonsLift.forEach(function ($common) {
            $common.addEventListener('click', controlClickEdge1);
        });
        function setAutoslidingTO() {
            window.clearTimeout(autoSlidingTO);
            var delay = +options.autoSlidingDelay || autoSlidingDelay;
            curSlide++;
            if (curSlide > numOfSlides)
                curSlide = 1;
            autoSlidingTO = setTimeout(function () {
                performSliding(curSlide);
            }, delay);
        }
        ;
        if (options.autoSliding || +options.autoSlidingDelay > 0) {
            if (options.autoSliding === false)
                return;
            autoSlidingActive = true;
            setAutoslidingTO();
            $slider.classList.add('m--with-autosliding');
            var triggerLayout = $slider.offsetTop;
            var delay = +options.autoSlidingDelay || autoSlidingDelay;
            delay += slidingDelay + slidingAT;
            $progressAS.forEach(function ($progress) {
                $progress.style.transition = 'transform ' + delay / 1000 + 's';
            });
        }
        $slider.querySelector('.fnc-nav__control:first-child').classList.add('m--active-control');
    }
    ;
    var fncSlider = function (sliderSelector, options) {
        var $sliders = $$(sliderSelector);
        $sliders.forEach(function ($slider) {
            _fncSliderInit($slider, options);
        });
    };
    window.fncSlider = fncSlider;
}());
fncSlider('.example-slider', { autoSlidingDelay: 3000 });

$(function() {
    //鼠标上去之后显示左右的切换图片的按钮
    $('.fnc-slider').hover(function(){
        $('.dot-commonRight')[0].style.display = 'block';
        $('.dot-commonLift')[0].style.display = 'block';
    },function(){
        $('.dot-commonRight')[0].style.display = 'none';
        $('.dot-commonLift')[0].style.display = 'none';
    });
});

