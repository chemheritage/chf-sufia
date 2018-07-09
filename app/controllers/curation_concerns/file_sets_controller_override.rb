CurationConcerns::FileSetsController.show_presenter = CHF::FileSetPresenter

def show
  super
end

# def to_child_work(params)
#   byebug
#   redirect_to '/concern/parent/x346d4165/file_sets/n296wz13w'
# end

# #If this needs to go somewhere else.... let's put it somewhere else.
class CurationConcerns::FileSetsController
   def to_child_work(params)
      puts "EDDIE WAZ HERE"
      puts "EDDIE WAZ HERE"
      puts "EDDIE WAZ HERE"
      puts "EDDIE WAZ HERE"
      puts "EDDIE WAZ HERE"
      puts "EDDIE WAZ HERE"

     byebug
     redirect_to 'http://localhost:3000/concern/parent/x346d4165/file_sets/n296wz13w'
   end
 end

