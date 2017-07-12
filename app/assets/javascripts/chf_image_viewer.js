// A JS 'class' for dealing with the image viewer

function ChfImageViewer(element) {
  this.element = element;
  this.initModal(document.querySelector("#chf-image-viewer-modal"));
}

ChfImageViewer.prototype.viewerPathComponentRe = /\/viewer\/(\w+)$/;

ChfImageViewer.prototype.show = function(id) {
  if (document.activeElement && document.activeElement.getAttribute("data-trigger") == "chf_image_viewer") {
    this.previousFocus = document.activeElement;
  }

  if (typeof this.viewer == "undefined") {
    this.initOpenSeadragon();
  }

  this.totalCount = parseInt(document.querySelector(".viewer-thumbs[data-total-count]").getAttribute("data-total-count"));
  if (this.totalCount == 1) {
    // hide multi-item-relevant controls
    this.hideUiElement(document.querySelector("#viewer-pagination"));
    this.hideUiElement(document.querySelector("#viewer-right"));
    this.hideUiElement(document.querySelector("#viewer-left"));
    this.hideUiElement(document.querySelector("#viewer-thumbs"));
  }

  if (! OpenSeadragon.supportsFullScreen) {
    this.hideUiElement(document.querySelector("#viewer-fullscreen"));
  }
  if (! this.viewer.drawer.canRotate()) {
    //OSD says no rotate
    this.hideUiElement(document.querySelector("#viewer-rotate-right"));
  }

  var selectedThumb;
  // find the thumb
  if (id) {
    selectedThumb = document.querySelector(".viewer-thumb-img[data-member-id='" + id + "']");
  }
  if (! selectedThumb) {
    // just use the first one
    selectedThumb = document.querySelector(".viewer-thumb-img");
  }
  this.selectThumb(selectedThumb);

  // show the viewer
  $(this.modal).modal("show");
  this.scrollSelectedIntoView();
};

// position can be 'start', 'end'
ChfImageViewer.prototype.scrollSelectedIntoView = function(position) {
  // only if the selected thing is not currently in scroll view, scroll
  // it to be so.
  // https://stackoverflow.com/a/16309126/307106

  var elem = this.selectedThumb;

  var container = $(".viewer-thumbs");

  var contHeight = container.height();
  var contTop = container.scrollTop();
  var contBottom = contTop + contHeight ;

  var contWidth = container.width();
  var contLeft = container.scrollLeft();
  var contRight = contLeft + contWidth;


  var elemTop = $(elem).offset().top - container.offset().top;
  var elemBottom = elemTop + $(elem).height();
  var elemLeft = $(elem).offset().left - container.offset().left;
  var elemRight = elemLeft + $(elem).width();

  var isTotal = (elemTop >= 0 && elemBottom <= contHeight && elemLeft >= 0 && elemRight <= contWidth);

  if (! isTotal) {
    if (position == "end") {
      this.selectedThumb.scrollIntoView(false);
    } else {
      this.selectedThumb.scrollIntoView();
    }
  }
}

ChfImageViewer.prototype.hide = function() {
  if (OpenSeadragon.isFullScreen()) {
    OpenSeadragon.exitFullScreen();
  }
  $(this.modal).modal("hide");
  this.removeLocationUrl();
  this.restoreFocus();
};


ChfImageViewer.prototype.restoreFocus =  function() {
  if(this.previousFocus) {
    this.previousFocus.focus();
    this.previousFocus = undefined;
  }
};

ChfImageViewer.prototype.addLoading =  function() {
  this.loadingSpinnerDisplayed = true;
  $('.viewer-image').addClass('viewer-image-loading');
}

ChfImageViewer.prototype.removeLoading =  function() {
  if (this.loadingSpinnerDisplayed) {
    $('.viewer-image').removeClass('viewer-image-loading');
    this.loadingSpinnerDisplayed = false;
  }
};

ChfImageViewer.prototype.selectThumb = function(thumbElement) {
  this.selectedThumb = thumbElement;

  // toggle classes, sorry some jQuery
  $('.viewer-thumbs .viewer-thumb-selected').removeClass('viewer-thumb-selected')
  thumbElement.classList.add('viewer-thumb-selected');

  var id = thumbElement.getAttribute('data-member-id');
  var index = thumbElement.getAttribute('data-index');
  var shouldShowInfo = thumbElement.getAttribute('data-member-should-show-info') == "true";
  var title = thumbElement.getAttribute('data-title');
  var linkUrl = thumbElement.getAttribute('data-member-show-url');
  var downloadOriginalUrl = thumbElement.getAttribute('data-member-dl-original-url');
  var downloadJpegUrl = thumbElement.getAttribute('data-member-dl-jpeg-url');
  var tileSource = thumbElement.getAttribute('data-tile-source');

  this.addLoading();

  this.viewer.open(tileSource);

  document.querySelector('*[data-hook="viewer-navbar-title-label"]').textContent = title;
  document.querySelector('*[data-hook="viewer-navbar-info-link"]').href = linkUrl;
  document.getElementsByClassName('viewer-pagination-numerator').item(0).textContent = index;

  var originalLink = document.querySelector('#chf-image-viewer *[data-content-hook=dl-original-link]');
  if (originalLink) { originalLink.setAttribute('href', downloadOriginalUrl); }
  var jpegLink = document.querySelector('#chf-image-viewer *[data-content-hook=dl-jpeg-link]');
  if (jpegLink) { jpegLink.setAttribute('href', downloadJpegUrl); }

  if (shouldShowInfo) {
    // spacer shows up when info doesn't.
    this.showUiElement(document.querySelector('#viewer-member-info'));
    this.hideUiElement(document.querySelector('#viewer-spacer'));
  } else {
    this.hideUiElement(document.querySelector('#viewer-member-info'));
    this.showUiElement(document.querySelector('#viewer-spacer'));
  }

  // show/hide next/prev as appropriate
  if (index <= 1) {
    this.hideUiElement(document.querySelector("#viewer-left"));
  } else if ( this.totalCount != 1 ) {
    this.showUiElement(document.querySelector("#viewer-left"));
  }

  if (index >= this.totalCount) {
    this.hideUiElement(document.querySelector("#viewer-right"));
  } else if ( this.totalCount != 1 ) {
    this.showUiElement(document.querySelector("#viewer-right"));
  }

  this.setLocationUrl();
};

ChfImageViewer.prototype.next = function() {
  var nextElement = this.selectedThumb.nextElementSibling;
  if (nextElement) {
    this.selectThumb(nextElement);
    this.scrollSelectedIntoView("start");
  }
};

ChfImageViewer.prototype.prev = function() {
  var prevElement = this.selectedThumb.previousElementSibling;
  if (prevElement) {
    this.selectThumb(prevElement);
    this.scrollSelectedIntoView("end");
  }
};

ChfImageViewer.prototype.setLocationUrl = function() {
  var currentPath = location.pathname;
  var selectedID = this.selectedThumb.getAttribute('data-member-id');

  var newPath;

  if (currentPath.match(this.viewerPathComponentRe)) {
    newPath = currentPath.replace(this.viewerPathComponentRe, '/viewer/' + encodeURIComponent(selectedID));
  } else if (currentPath.match(/\/$/)) {
    newPath = currentPath + 'viewer/' + encodeURIComponent(selectedID);
  } else {
    newPath = currentPath + '/viewer/' + encodeURIComponent(selectedID);
  }

  history.replaceState({}, "", this.locationWithNewPath(newPath));
};

ChfImageViewer.prototype.removeLocationUrl = function() {
  if (location.pathname.match(this.viewerPathComponentRe)) {
    var newPath = location.pathname.replace(this.viewerPathComponentRe, '');
    history.replaceState({}, "", this.locationWithNewPath(newPath));
  }
}

ChfImageViewer.prototype.locationWithNewPath = function(newPath) {
  var newUrl = location.protocol + '//' + location.host + newPath;
  if (location.query) {
    newUrl += '?' + location.query;
  }
  if (location.hash) {
    newUrl += '#' + location.hash;
  }
  return newUrl;
};

ChfImageViewer.prototype.onKeyDown = function(event) {
  if (this.dropdownVisible) {
    return;
  }

  // Many parts copied/modified from OSD source, no way to proxy to it directly.
  // This one expects a jQuery event.
  // And has a couple custom mappings added to it.
  // https://github.com/openseadragon/openseadragon/blob/e81e30c81cd8be566a4c8011ad7f592ac1df30d3/src/viewer.js#L2414-L2499
  if ( !event.preventDefaultAction && !event.ctrl && !event.alt && !event.meta ) {
      switch( event.keyCode ){
          case 27: // ESC
            this.hide();
            return false;
          case 38://up arrow
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(1.1);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, -40)));
              }
              this.viewer.viewport.applyConstraints();
              return false;
          case 40://down arrow
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(0.9);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, 40)));
              }
              this.viewer.viewport.applyConstraints();
              return false;
          case 37://left arrow
              if (event.shiftKey) {
                // custom CHF, next doc
                this.prev();
                return false;
              } else {
                this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(-40, 0)));
                this.viewer.viewport.applyConstraints();
                return false;
              }
          case 39://right arrow
            if (event.shiftKey) {
              // custom CHF, prev doc
              this.next();
              return false;
            } else {
              this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(40, 0)));
              this.viewer.viewport.applyConstraints();
              return false;
            }
          default:
              //console.log( 'navigator keycode %s', event.keyCode );
              return true;
      }
  } else {
      return true;
  }
}

ChfImageViewer.prototype.onKeyPress = function(event) {
  if (this.dropdownVisible) {
    return;
  }

  // Many parts copied/modified from OSD source, no way to proxy to it directly.
  // This one expects a jQuery event.
  // https://github.com/openseadragon/openseadragon/blob/e81e30c81cd8be566a4c8011ad7f592ac1df30d3/src/viewer.js#L2414-L2499
  if ( !event.preventDefaultAction && !event.ctrlKey && !event.altKey && !event.metaKey ) {
        switch( event.which ){
          case 46: //.|>
          case 62: //.|>
            this.next();
            return false;
          case 44: //,|<
          case 50: //,|<
            this.prev();
            return false;
          case 43://=|+
          case 61://=|+
              this.viewer.viewport.zoomBy(1.1);
              this.viewer.viewport.applyConstraints();
              return false;
          case 45://-|_
              this.viewer.viewport.zoomBy(0.9);
              this.viewer.viewport.applyConstraints();
              return false;
          case 48://0|)
              this.viewer.viewport.goHome();
              this.viewer.viewport.applyConstraints();
              return false;
          case 119://w
          case 87://W
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(1.1);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, -40)));
              }
              this.viewer.viewport.applyConstraints();
              return false;
          case 115://s
          case 83://S
              if ( event.shiftKey ) {
                  this.viewer.viewport.zoomBy(0.9);
              } else {
                  this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(0, 40)));
              }
              this.viewer.viewport.applyConstraints();
              return false;
          case 97://a
              this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(-40, 0)));
              this.viewer.viewport.applyConstraints();
              return false;
          case 100://d
              this.viewer.viewport.panBy(this.viewer.viewport.deltaPointsFromPixels(new OpenSeadragon.Point(40, 0)));
              this.viewer.viewport.applyConstraints();
              return false;
          default:
              //console.log( 'navigator keycode %s', event.keyCode );
              return true;
        }
    } else {
        return true;
    }
};


// We use the bootstrap modal, because it already handles
// tricky issues of full-body scroll and tabindex. We need to
// restyle some of it in CSS to be full-screen.
ChfImageViewer.prototype.initModal = function(modalElement) {
  this.modal = modalElement;
  this.modal = $(this.modal).modal({
    show: false,
    keyboard: false
  });
};

ChfImageViewer.prototype.initOpenSeadragon = function() {
  // we only want a rotate-right, not rotate-left. Can't figure
  // out how to get OSD to do that, and not try to fetch rotate-left
  // images, except giving it a fake rotate-left
  // button, sorry!
  var dummyRotateLeft = document.createElement("div");
  dummyRotateLeft.id ='dummy-osd-rotate-left';
  dummyRotateLeft.style.display = 'none';
  document.body.appendChild(dummyRotateLeft);

  this.viewer = OpenSeadragon({
    id:            'openseadragon-container',
    showRotationControl: true,
    showFullPageControl: false,

    // we use our own controls
    zoomInButton:       "viewer-zoom-in",
    zoomOutButton:      "viewer-zoom-out",
    homeButton:         "viewer-zoom-fit",
    rotateRightButton:  "viewer-rotate-right",
    rotateLeftButton:   "dummy-osd-rotate-left",

    tabIndex: "",

    gestureSettingsTouch: {
      pinchRotate: true
    }
  });

  // OSD seems to insist on setting inline style position:relative on it's
  // own container. If we just change that to 'absolute', then it properly fills
  // the space of it's container on our page the way we want it to. There
  // must be a better way to do this, sorry for the hack.
  this.viewer.container.style.position = "absolute";

  // The OSD 'open' event is fired when it tries to request an image,
  // but hasn't neccesarily received it yet. Riiif can be really slow.
  // The first 'tile-drawing' event means we've actually got _something_
  // to paint on screen, better later point to remove spinner.
  var _self = this;
  this.viewer.addHandler("tile-drawing", function() { _self.removeLoading() } );
};

ChfImageViewer.prototype.hideUiElement = function(element) {
  if (document.activeElement == element) {
    // If it was focused and we're hiding it, make sure to switch focus
    // to modal, so keyboard shortcuts and tab still works right.
    this.modal.focus();
  }
  element.style.display = "none";
};

ChfImageViewer.prototype.showUiElement = function(element) {
  element.style.display = "";
};

jQuery(document).ready(function($) {
  var viewerElement = document.getElementById('chf-image-viewer');

  if (viewerElement) {
    // lazily create a single page-wide ChfImageViewer helper
    var _chf_image_viewer;
    var chf_image_viewer = function() {
      if (typeof _chf_image_viewer == 'undefined') {
        _chf_image_viewer = new ChfImageViewer(viewerElement);
      }

      return _chf_image_viewer;
    };

    var viewerUrlMatch = ChfImageViewer.prototype.viewerPathComponentRe.exec(location.pathname);
    if (viewerUrlMatch != null) {
      // we have a viewer thumb in URL, let's load the viewer on page load!
      chf_image_viewer().show(viewerUrlMatch[1]);
    }

    $(chf_image_viewer().modal).on("keypress.chf_image_viewer", function(event) {
      chf_image_viewer().onKeyPress(event);
    });
    $(chf_image_viewer().modal).on("keydown.chf_image_viewer", function(event) {
      chf_image_viewer().onKeyDown(event);
    });
    // Record whether dropdown is showing, so we can avoid keyboard handling
    // for viewer when it is, let the dropdown have it. Prob better to
    // do this with jquery on/off, but this was easiest for now.
    $(chf_image_viewer().modal).on("show.bs.dropdown", function(event) {
      chf_image_viewer().dropdownVisible = true;
    });
    $(chf_image_viewer().modal).on("hide.bs.dropdown", function(event) {
      chf_image_viewer().dropdownVisible = false;
    });

    $(document).on("click", "*[data-trigger='chf_image_viewer']", function(event) {
      event.preventDefault();
      var id = this.getAttribute('data-member-id');
      chf_image_viewer().show(id);

      // GA
      _gaq.push(['_trackEvent',
           'ImageViewer',
           'fileSetId',
           id
          ]);
    });

    // with keyboard-tab nav to our thumbs, let return/space trigger click as for normal links
    $(document).on("keydown", "*[data-trigger='chf_image_viewer']", function(event) {
      // space or enter trigger click for keyboard control
      if (event.which == 13 || event.which == 32) {
        event.preventDefault();
        $(this).trigger("click");
      }
    });

    // keyboard-tab and clicks on the overlay controls within thumb should
    // not propagate to click on thumb itself!  Keyboard-tav return/space
    // should trigger what the buttons do though.
    $(document).on("keydown keypress click", ".show-page-image-bar button, .show-page-image-bar a", function(event) {
      if (event.type == "click") {
        event.stopPropagation();
      } else if (event.which == 13 || event.which == 32) { // space or return
        event.stopPropagation();
        $(this).trigger("click");
      }
    });


    $(document).on("click", "*[data-trigger='chf_image_viewer_close']", function(event) {
      event.preventDefault();
      chf_image_viewer().hide();
    });

    $(document).on("click", "*[data-trigger='change-viewer-source']", function(event) {
      event.preventDefault();
      chf_image_viewer().selectThumb(this);
    });

    $(document).on("keypress", "*[data-trigger='change-viewer-source']", function(event) {
      // space or enter trigger click for keyboard control
      if (event.which == 13 || event.which == 32) {
        event.preventDefault();
        $(this).trigger("click");
      }
    });

    $(document).on("click", "*[data-trigger='viewer-next']", function(event) {
      event.stopPropagation();
      chf_image_viewer().next();
    });

    $(document).on("click", "*[data-trigger='viewer-prev']", function(event) {
      event.stopPropagation();
      chf_image_viewer().prev();
    });

    $(document).on("click", "*[data-trigger='viewer-fullscreen']", function(event) {
      // Use OSD's cross-browser fullscreen implementation, great.
      if (OpenSeadragon.isFullScreen()) {
        OpenSeadragon.exitFullScreen();
      } else {
        OpenSeadragon.requestFullScreen( document.body );
      }
    });
  }
});
