/*
 Copyright (c) 2012-2019, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

var ENTER_KEYCODE = 13;

var _path = "/";
var _pendingReloads = [];
var _reloadingDisabled = 0;

function formatFileSize(bytes) {
  if (bytes >= 1000000000) {
    return (bytes / 1000000000).toFixed(2) + " GB";
  }
  if (bytes >= 1000000) {
    return (bytes / 1000000).toFixed(2) + " MB";
  }
  return (bytes / 1000).toFixed(2) + " KB";
}

function _showError(message, textStatus, errorThrown) {
  $("#alerts").prepend(
    tmpl("template-alert", {
      level: "danger",
      title: (errorThrown != "" ? errorThrown : textStatus) + ": ",
      description: message,
    })
  );
}

function _disableReloads() {
  _reloadingDisabled += 1;
}

function _enableReloads() {
  _reloadingDisabled -= 1;

  if (_pendingReloads.length > 0) {
    _reload(_pendingReloads.shift());
  }
}

function _reload(path) {
  // if (_reloadingDisabled) {
  //   if ($.inArray(path, _pendingReloads) < 0) {
  //     _pendingReloads.push(path);
  //   }
  //   return;
  // }

  if (path == "/") {
    $("#create-folder").show();
  } else {
    $("#create-folder").hide();
  }

  _disableReloads();
  $.ajax({
    url: "list",
    type: "POST",
    data: { path: path },
    dataType: "json",
  })
    .fail(function (jqXHR, textStatus, errorThrown) {
      _showError(
        'Failed retrieving contents of "' + path + '"',
        textStatus,
        errorThrown
      );
    })
    .done(function (data, textStatus, jqXHR) {
      
      _device = data.device;

      var scrollPosition = $(document).scrollTop();

     document.title = data.title;

     $('#page-title').html($(
      tmpl("template-title", {
        title: data.title
      })
    ));
    
    $('#description').html($(
        tmpl("template-description", {
          description: data.description
        })
      ));

      $('#copyright').html($(
        tmpl("template-copyright", {
          website: data.website,
          copyright: data.copyright
        })
      ));
      
      //console.log(data);

      if (path != _path) {
        $("#path").empty();
        if (path == "/") {
          $("#path").append('<li class="active">' + _device + "</li>");
        } else {
          $("#path").append(
            '<li data-path="/"><a href="#">' + _device + "</a></li>"
          );

          var components = path.split("/");
          for (var i = 0; i < components.length - 1; ++i) {
            if (components[i] != "") {
              var subpath = "/" + components.slice(0, i + 1).join("/") + "/";
              $("#path").append(
                '<li data-path="' +
                  subpath +
                  '"><a href="#">' +
                  components[i] +
                  "</a></li>"
              );
            }
          }
          $("#path > li").click(function (event) {
            _reload($(this).data("path"));
            event.preventDefault();
          });
          $("#path").append(
            '<li class="active">' + components[components.length - 1] + "</li>"
          );
        }
        _path = path;
      }

      $("#listing").empty();
      for (var i = 0, file; (file = data.files[i]); ++i) {
        $(tmpl("template-listing", file)).data(file).appendTo("#listing");
      }

      $(".edit").editable(
        function (value, settings) {
          var name = $(this).parent().parent().data("name");
          if (value != name) {
            var path = $(this).parent().parent().data("path");
            $.ajax({
              url: "move",
              type: "POST",
              data: { oldPath: path, newPath: _path + "/" + value },
              dataType: "json",
            })
              .fail(function (jqXHR, textStatus, errorThrown) {
                _showError(
                  'Failed to edit "' + path + '" to "' + _path + value + '"',
                  textStatus,
                  errorThrown
                );
              })
              .always(function () {
                _reload(_path);
              });
          }
          return value;
        },
        {
          onedit: function (settings, original) {
            _disableReloads();
          },
          onsubmit: function (settings, original) {
            _enableReloads();
          },
          onreset: function (settings, original) {
            _enableReloads();
          },
          tooltip: "Click to rename...",
        }
      );

      $(".button-download").click(function (event) {
        var path = $(this).parent().parent().data("path");
        setTimeout(function () {
          window.location = "download?path=" + encodeURIComponent(path);
        }, 0);
      });

      $(".button-open").click(function (event) {
        var path = $(this).parent().parent().data("path");

        _reload(path);
      });

      $(".button-move").click(function (event) {
        var path = $(this).parent().parent().data("path");
        if (path[path.length - 1] == "/") {
          path = path.slice(0, path.length - 1);
        }
        $("#move-input").data("path", path);
        $("#move-input").val(path);
        $("#move-modal").modal("show");
      });

      $(".button-delete").click(function (event) {
        if (window.confirm("Are you sure？")) {
          var filename = $(this).parent().parent().data("path");

          $.ajax({
            url: "delete",
            type: "POST",
            data: { filename: filename },
            dataType: "json",
          })
            .fail(function (jqXHR, textStatus, errorThrown) {
              _showError(
                'Failed to delete: "' +
                  filename +
                  '"  Error:' +
                  jqXHR.responseJSON.message,
                textStatus,
                errorThrown
              );
            })
            .done(function (data) {
              _reload("/");
            });
        }
      });

      $(document).scrollTop(scrollPosition);
    })
    .always(function () {
      //
      _enableReloads();
    });
}

$(document).ready(function () {
  // Workaround Firefox and IE not showing file selection dialog when clicking on "upload-file" <button>
  // Making it a <div> instead also works but then it the button doesn't work anymore with tab selection or accessibility
  $("#upload-file").click(function (event) {
    $("#fileupload").click();
  });

  // Prevent event bubbling when using workaround above
  $("#fileupload").click(function (event) {
    event.stopPropagation();
  });

  $("#fileupload").fileupload({
    dropZone: $(document),
    pasteZone: null,
    autoUpload: true,
    sequentialUploads: true,
    maxChunkSize: 100000000,
    limitConcurrentUploads: 1,
    // forceIframeTransport: true,

    url: "uploading",
    type: "POST",
    dataType: "json",

    start: function (e, data) {
      $(".uploading").show();
    },

    send: function (e, data) {
      $(".uploading").show();

      $.ajax({
        url: "startUpload",
        type: "POST",
        data: { name: data.files[0].name, path: _path },
        dataType: "json",
      }).fail(function (jqXHR, textStatus, errorThrown) {
        _showError("Start upload file failed!", textStatus, errorThrown);
      });
    },

    stop: function (e) {
      $(".uploading").hide();

      $.ajax({
        url: "finishUploaded",
        type: "POST",
        dataType: "json",
      });

      setTimeout(function () {
        _reload(_path);
      }, 1500);
    },

    add: function (e, data) {
      var file = data.files[0];
      data.formData = {
        path: _path,
      };
      data.context = $(
        tmpl("template-uploads", {
          path: _path + file.name,
        })
      ).appendTo("#uploads");
      var jqXHR = data.submit();
      data.context.find("button").click(function (event) {
        jqXHR.abort();
      });
    },

    progress: function (e, data) {
      var progress = parseInt((data.loaded / data.total) * 100, 10);
      data.context.find(".progress-bar").css("width", progress + "%");
    },

    done: function (e, data) {
      $.ajax({
        url: "uploadDone",
        type: "POST",
        dataType: "json",
        data: { name: data.files[0].name },
      });
    },

    chunkalways: function (e, data) {},

    fail: function (e, data) {
      var file = data.files[0];
      _reload(_path);
      if (data.errorThrown != "abort") {
        _showError(
          'Upload failed "' + file.name + '" to "' + _path + '"',
          data.textStatus,
          data.errorThrown
        );
      }
    },

    always: function (e, data) {
      data.context.remove();
    },
  });

  $("#create-input").keypress(function (event) {
    if (event.keyCode == ENTER_KEYCODE) {
      $("#create-confirm").click();
    }
  });

  $("#create-modal").on("shown.bs.modal", function (event) {
    $("#create-input").focus();
    $("#create-input").select();
  });

  $("#create-folder").click(function (event) {
    $("#create-input").val("Untitled folder");
    $("#create-modal").modal("show");
  });

  $("#create-confirm").click(function (event) {
    $("#create-modal").modal("hide");
    var name = $("#create-input").val();
    var createFolder = _path;
    if (!createFolder.endsWith("/")) {
      createFolder += "/" + name;
    } else {
      createFolder += name;
    }
    if (name != "") {
      $.ajax({
        url: "create",
        type: "POST",
        data: { path: createFolder },
        dataType: "json",
      })
        .fail(function (jqXHR, textStatus, errorThrown) {
          //
          _showError(
            'Failed to create folder  "' +
              name +
              '" in "' +
              _path +
              '" <br>Error:' +
              jqXHR.responseJSON.message,
            textStatus,
            errorThrown
          );
        })
        .always(function () {
          _reload(_path);
        });
    }
  });

  $("#move-input").keypress(function (event) {
    if (event.keyCode == ENTER_KEYCODE) {
      $("#move-confirm").click();
    }
  });

  $("#move-modal").on("shown.bs.modal", function (event) {
    $("#move-input").focus();
    $("#move-input").select();
  });

  $("#move-confirm").click(function (event) {
    $("#move-modal").modal("hide");
    var oldPath = $("#move-input").data("path");
    var newPath = $("#move-input").val();
    if (newPath != "" && newPath[0] == "/" && newPath != oldPath) {
      $.ajax({
        url: "move",
        type: "POST",
        data: { oldPath: oldPath, newPath: newPath },
        dataType: "json",
      })
        .fail(function (jqXHR, textStatus, errorThrown) {
          _showError(
            'Failed moving "' + oldPath + '" to "' + newPath + '"',
            textStatus,
            errorThrown
          );
        })
        .always(function () {
          _reload(_path);
        });
    }
  });

  $("#reload").click(function (event) {
    _reload(_path);
  });

  _reload("/");
});
