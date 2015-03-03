var currentPage = -1;
var pages = [
  "0001",
  "0002",
  "0003",
  "0004",
  "0005",
  "0006",
  "0007",
  "0008",
  "0009",
  "0010",
  "0011",
  "0012",
];
var pageExitConditions = [{
  verify: function(data) {
    return data.expr == "(sqrt 144)";
  }
}, {
  verify: function(data) {
    return data.expr == "(expt (sqrt 144) (/ 4 2))";
  }
}, {
  verify: function(data) {
    return false;
  }
}, {
  verify: function(data) {
    return data.expr == "(define lower 1)";
  }
}, {
  verify: function(data) {
    return data.expr == "(define upper 100)";
  }
}, {
  verify: function(data) {
    return data.expr == "(guess)";
  }
}, {
  verify: function(data) {
    return false;
  }
}, {
  verify: function(data) {
    return false;
  }
}, {
  verify: function(data) {
    return false;
  }
}, {
  verify: function(data) {
    return data.expr == "(start 30 1)";
  }
}, {
  verify: function(data) {
    return false;
  }
}, {
  verify: function(data) {
    return false;
  }
}];

function goToPage(pageNumber) {
  if (pageNumber == currentPage || pageNumber < 0 || pageNumber >= pages.length) {
    return;
  }

  currentPage = pageNumber;

  var block = $("#guide");
  block.fadeOut(function(e) {
    block.load("/tutorial", {
      'page': pages[pageNumber]
    }, function() {
      block.fadeIn();
      guideUpdated();
    });
  });
}

function setupLink(url) {
  return function(e) {
    $("#guide").load(url, function(data) {
      $("#guide").html(data);
    });
  }
}

function setupExamples(controller) {
  $(".code").click(function(e) {
    controller.promptText($(this).text());
  });
}

function getStep(n, controller) {
  $("#tuttext").load("tutorial", {
    step: n
  }, function() {
    setupExamples(controller);
  });
}

function eval_racket(code) {
  var data;
  $.ajax({
    url: evalUrl,
    data: {
      expr: code
    },
    async: false,
    success: function(res) {
      data = res;
    },
  });
  return data;
}

function complete_racket(str) {
  var data;
  $.ajax({
    url: evalUrl,
    data: {
      complete: str
    },
    async: false,
    success: function(res) {
      data = res;
    },
  });
  return data;
}

function doCommand(input) {
  if (input.match(/^gopage /)) {
    goToPage(parseInt(input.substring("gopage ".length)));
    return true;
  }
  switch (input) {
    case 'start':
      goToPage(0);
      return true;
    case 'next':
      goToPage(currentPage + 1);
      return true;
    case 'game on!':
      goToPage(3);
      return true;
    case 'bang bang':
      goToPage(7);
      return true;
    case 'brutal':
      goToPage(8);
      return true;
    case 'popcorn':
      goToPage(9);
      return true;
    case 'after party':
      goToPage(11);
      return true;
    case 'back':
      goToPage(currentPage - 1);
      return true;
    case 'reset':
      goToPage(0);
      controller.reset()
      return true;
    default:
      return false;
  }
}

function onValidate(input) {
  return (input != "");
}

function onComplete(line) {
  var input = $.trim(line);
  // get the prefix that won't be completed
  var prefix = line.replace(RegExp("(\\w|[-])*$"), "");
  var data = complete_racket(input);

  // handle error
  if (data.error) {
    controller.commandResult(data.message, "jquery-console-message-error");
    return [];
  } else {
    var res = JSON.parse(data.result);
    for (var i = 0; i < res.length; i++) {
      res[i] = prefix + res[i];
    }
    return res;
  }
}

function parensBalanced(string) {
  var parentheses = "[]{}()",
    stack = [],
    i, character, bracePosition;

  for (i = 0; character = string[i]; i++) {
    bracePosition = parentheses.indexOf(character);

    if (bracePosition === -1) {
      continue;
    }

    if (bracePosition % 2 === 0) {
      stack.push(bracePosition + 1); // push next expected brace position
    } else {
      if (stack.pop() !== bracePosition) {
        return false;
      }
    }
  }

  return stack.length === 0;
}

function onHandle(line, report) {
  var input = $.trim(line);
  // clear console, save history
  if (input == 'clear') {
    controller.reset()
    return;
  } else if (parensBalanced(input) == false) {
    controller.continuedPrompt = true;
  } else {
    controller.continuedPrompt = false;
    if (doCommand(input)) {
      report();
      return;
    }
    // perform evaluation. Result is a list to handle (values ...)
    var datas = eval_racket(input);
    var results = [];
    for (var i = 0; i < datas.length; i++) {
      var data = datas[i];
      // handle error
      if (data.error) {
        // remove context from error message
        error_message = data.message.replace(/context...:[\s\S]*/, '');
        results.push({
          msg: error_message,
          className: "jquery-console-message-error"
        });
      } // handle page
      else if (currentPage >= 0 && pageExitConditions[currentPage].verify(
          data)) {
        goToPage(currentPage + 1);
      }
      // display expr results
      if (/#\"data:image\/png;base64,/.test(data.result)) {
        $('.jquery-console-inner').append('<img src="' + data.result.substring(
          2) + " /><br />");
        controller.scrollToBottom();
        results.push({
          msg: "",
          className: "jquery-console-message-value"
        });
      } else {
        results.push({
          msg: data.result,
          className: "jquery-console-message-value"
        });
      }
    }
    return results;
  }
}

/**
 * This should be called anytime the guide div is updated so it can rebind event listeners.
 * Currently this is just to make the code elements clickable.
 */
function guideUpdated() {
  $("#guide code.expr").each(function() {
    $(this).css("cursor", "pointer");
    $(this).attr("title", "Click to insert '" + $(this).text() +
      "' into the REPL.");
    $(this).click(function(e) {
      controller.promptText($(this).text());
      controller.inner.click();
      // trigger Enter
      var e = jQuery.Event("keydown");
      e.keyCode = 13;
      controller.typer.trigger(e);
    });
  });
}

var controller;
$(document).ready(function() {
  controller = $("#console").console({
    welcomeMessage: "read-eval-print-loop ready",
    promptLabel: '> ',
    continuedPromptLabel: '   ',
    commandValidate: onValidate,
    commandHandle: onHandle,
    completeHandle: onComplete,
    autofocus: true,
    animateScroll: true,
    promptHistory: true,
    fadeOnReset: true,
    ctrlCodes: true,
    cols: 1
  });
  $("#about").click(setupLink("about"));
  guideUpdated();
});
