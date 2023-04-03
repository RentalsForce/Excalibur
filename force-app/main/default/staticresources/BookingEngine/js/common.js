$(function(){
	var arrival = new Date();
	arrival.setDate(arrival.getDate()-1);

	var departure = new Date();
	departure.setDate(departure.getDate()+1);
	$('[data-chosedate="default"]').datepicker();

	$('[data-chosetime="default"]').timepicker({
	});

	$('[data-chosedate="arrival"]').datepicker({
		startDate: arrival
	});
	$('[data-chosedate="departure"]').datepicker({
		startDate: departure
	});

	// fix departure_Date >= arrival_Date
	$('[data-chosedate="arrival"]').change(function(){
		var depart = $(this).datepicker('getDate');
		depart.setDate(depart.getDate() + 1);
		$('[data-chosedate="departure"]').datepicker('setStartDate', depart);
		$('[data-chosedate="departure"]').datepicker('setDate', depart);
	});

	$('.more a').on("click", function(e) {
		e.preventDefault();
		$(this).parent().prev().css("height", "auto");
	});

	$('.next').on("click", function() {
		$(this).parents('.content').removeClass('active');
		$(this).parents('.content').next().addClass('active');
		$('#process-step .content').removeClass('active');
		var step = $(this).data('step');
		$('#process-step .'+step).addClass('active');
		$('#process-step').removeClass();
		$('#process-step').addClass(step);
	});
	$('.back-step').on("click", function() {
		$(this).parents('.content').removeClass('active');
		$(this).parents('.content').prev().addClass('active');

		$('#process-step .content').removeClass('active');
		var step = $(this).data('step');
		$('#process-step .'+step).addClass('active');
		$('#process-step').removeClass();
		$('#process-step').addClass(step);
	});
	$('.number span').on("click", function() {

		var step = $(this).data('step');
		$('.page-checkout .body .content').removeClass('active');
		$('.'+step).addClass('active');

		$('#process-step .content').removeClass('active');
		
		$('#process-step .'+step).addClass('active');
		$('#process-step').removeClass();
		$('#process-step').addClass(step);
	});

	$("#checkall").click(function () {
	    $(".data-table .checkbox").prop('checked', $(this).prop('checked'));
	});
});


// resize
// ==================================================
( function( window ) {
	
		'use strict';
	
		// class helper functions from bonzo https://github.com/ded/bonzo
	
		function classReg( className ) {
			return new RegExp("(^|\\s+)" + className + "(\\s+|$)");
		}
	
		var hasClass, addClass, removeClass;
	
		if ( 'classList' in document.documentElement ) {
			hasClass = function( elem, c ) {
				return elem.classList.contains( c );
			};
			addClass = function( elem, c ) {
				elem.classList.add( c );
			};
			removeClass = function( elem, c ) {
				elem.classList.remove( c );
			};
		}
		else {
			hasClass = function( elem, c ) {
				return classReg( c ).test( elem.className );
			};
			addClass = function( elem, c ) {
				if ( !hasClass( elem, c ) ) {
					elem.className = elem.className + ' ' + c;
				}
			};
			removeClass = function( elem, c ) {
				elem.className = elem.className.replace( classReg( c ), ' ' );
			};
		}
	
		function toggleClass( elem, c ) {
			var fn = hasClass( elem, c ) ? removeClass : addClass;
			fn( elem, c );
		}
	
		var classie = {
			// full names
			hasClass: hasClass,
			addClass: addClass,
			removeClass: removeClass,
			toggleClass: toggleClass,
			// short names
			has: hasClass,
			add: addClass,
			remove: removeClass,
			toggle: toggleClass
		};
	
		// transport
		if ( typeof define === 'function' && define.amd ) {
			// AMD
			define( classie );
		} else {
			// browser global
			window.classie = classie;
		}
	
	})( window );
	
	
	var ModalEffects = (function() {
	
		function init() {
	
			var overlay = document.querySelector( '.md-overlay' );
	
			[].slice.call( document.querySelectorAll( '.md-trigger' ) ).forEach( function( el, i ) {
	
				var modal = document.querySelector( '#' + el.getAttribute( 'data-modal' ) );
				var close, close1;
				if(modal){
					close = modal.querySelector( '.md-close' ),
					close1 = modal.querySelector( '.md-close1' );
				}

				function removeModal( hasPerspective ) {
					classie.remove( modal, 'md-show' );
	
					if( hasPerspective ) {
						classie.remove( document.documentElement, 'md-perspective' );
					}
				}
	
				function removeModalHandler() {
					removeModal( classie.has( el, 'md-setperspective' ) );
				}
	
				el.addEventListener( 'click', function( ev ) {
					classie.add( modal, 'md-show' );
					overlay.removeEventListener( 'click', removeModalHandler );
					overlay.addEventListener( 'click', removeModalHandler );
	
					if( classie.has( el, 'md-setperspective' ) ) {
						setTimeout( function() {
							classie.add( document.documentElement, 'md-perspective' );
						}, 25 );
					}
				});
	
				if(close!=null) {
					close.addEventListener( 'click', function( ev ) {
						ev.stopPropagation();
						removeModalHandler();
					});
				}
				if(close1!=null) {
					close1.addEventListener( 'click', function( ev ) {
						ev.stopPropagation();
						removeModalHandler();
					});
				}
	
	
			} );
	
		}
	
		init();
	
	})();

	// fix modal login only show 1 time
	$('.sign-in, .md-close').on("click", function () {
		$('#modal-login').toggleClass('md-show');
	});

	// more filter
	$('.more-btn').click(function(){
		$('.more-filter').slideToggle();
	});