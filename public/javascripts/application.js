// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// These are the Request Timers that limit the amount of requests that
// are sent to the server by waiting for the user to pause while typing
// before sending the request.

var rt = null;

function createSpinner() {
  // var img = new Image;
  // img.src = root_url + 'images/ajax-loader.gif';
  
  return new Element('img', { src: root_url + 'images/ajax-loader.gif', 'class': 'spinner', 'height': '11', 'width': '11' });
}

document.observe("dom:loaded", function() {
  // the element in which we will observe all clicks and capture
  // ones originating from pagination links
  var container = $(document.body);

  if(container) {
    container.observe('click', function(e) {
      var el = e.element();
      if (el.match('.pagination a')) {
        el.up('.pagination').insert(createSpinner());
        var ajax_request = new Ajax.Request(el.href, { method: 'post', parameters: $('search-form').serialize()  + '&authenticity_token=' + encodeURIComponent(auth_token)  });
        e.stop();
      }
    });
    
    // Ajax.Responders.register({
    //   onComplete: function(request, transport, json) {
    //     if(request.transport.status == 403){
    //       window.location = '/users/sign_in';
    //     }
    //   }
    // });
  }
});

/* Mouse Out Functions to Show and Hide Divs */

function isTrueMouseOut(e, handler) {
	if (e.type != 'mouseout') return false;
	var relTarget;
  if (e.relatedTarget) {
    relTarget = e.relatedTarget;
  } else if (e.type == 'mouseout') {
    relTarget = e.toElement;
  } else {
    relTarget = e.fromElement;
  }
// alert('relTarget type:' + relTarget.tagName + " - " + relTarget.innerHTML);
  while (relTarget && relTarget != handler) {
    relTarget = relTarget.parentNode;
  }
	return (relTarget != handler);
}

function hideOnMouseOut(elements){
  elements.each(function(element){
    var element = $(element);
    element.onmouseout = function(e, handler) {
      if (isTrueMouseOut(e||window.event, this)) this.hide();
    }
  });
}

function genericSearchRequest(url, token, form, params){
  new Ajax.Request(url, {asynchronous:true, evalScripts:true, method:'post', parameters: $(form).serialize() + params + '&_method=post' + '&authenticity_token=' + encodeURIComponent(token)});
}

function genericSearchUpdate(update, url, token, params){
  new Ajax.Updater(update, url, {asynchronous:true, evalScripts:true, method:'post', parameters: params+'&_method=post' + '&authenticity_token=' + encodeURIComponent(token)});  
}
