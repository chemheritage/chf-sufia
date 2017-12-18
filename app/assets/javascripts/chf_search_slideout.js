
// Arg should be container `form` object
function ChfSearchSlideout(element) {
  var _self = this;
  this.element = $(element);
  this.element.on("click touch hover focusin", function() {
    _self.open();
  });
}

ChfSearchSlideout.prototype.animationTime = 180;

ChfSearchSlideout.prototype.drawerElement = function() {
  return $(this.element).find('.search-options');
}

ChfSearchSlideout.prototype.open = function() {
  this.element.removeClass("closed").addClass("opened");
  this.installLeaveHandlers();
  this.drawerElement().slideDown(this.animationTime);
}

ChfSearchSlideout.prototype.close = function() {
  this.element.removeClass("opened").addClass("closed");
 this.drawerElement().slideUp(this.animationTime);
 this.removeLeaveHandlers();
}

ChfSearchSlideout.prototype.installLeaveHandlers = function() {
  var _self = this;
  this.element.on("mouseleave.chfSearchSlideout", function() {
    // if the text box or another input is focused, don't close.
    if (! $.contains(_self.element.get(0), $(':focus').get(0))) {
      _self.close();
    }
  });
  $("body").on("click.chfSearchSlideout touch.chfSearchSlideout focusin.chfSearchSlideout", function(e) {
    if (! $.contains(_self.element.get(0), e.target)) {
      _self.close();
    }
  });
}

ChfSearchSlideout.prototype.removeLeaveHandlers = function() {
  this.element.off(".chfSearchSlideout");
  $("body").off(".chfSearchSlideout");
}


jQuery(document).ready(function($) {
  new ChfSearchSlideout($(".nav-search-form"));
});
