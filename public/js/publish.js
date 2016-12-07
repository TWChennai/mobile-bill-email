$(document).ready(function() {
    $(".sendButton").click(function(e) {
      e.preventDefault();
      $(this).attr('value', 'Sending...');
      $(this).attr('disabled', 'disabled');
      var button = this;
      var es = new EventSource('/send-mail');      
      
      es.addEventListener('message', function(e){      
        $("#" + jQuery.parseJSON(e.data).index).removeClass('pending').addClass('done');
        console.log($('.pending').size());
        if($('.pending').size() == 0) {
          alert('Completed!');
          $(button).attr('value', 'completed');
          es.close();          
        }
      }, false);

      es.addEventListener('error', function(e) {
        if(es.readystate != EventSource.CLOSED) es.close();
      }, false);
    });

    $('#submitButton').on('click', function(e){
      e.preventDefault();
      var errors = "";
      
      if($('input[name=from_address]').val().trim() == "") {
        errors += "Enter Sender's 'From' email address\n";
      }

      if($('#office').find('option:selected').val() == "0") {
        errors += "Choose Office\n";
      }

      if(errors == "") {
        $('#uploadForm').submit();
      } else {
        alert(errors);
      }
    })
});