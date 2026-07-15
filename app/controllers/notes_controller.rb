class NotesController < ApplicationController
  def create
    @person = Person.find(params[:person_id])
    @note = @person.notes.build(note_params)

    if @note.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @person, notice: "Note added." }
      end
    else
      redirect_to @person, alert: @note.errors.full_messages.to_sentence
    end
  end

  def destroy
    @note = Note.find(params[:id])
    @note.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @note.person, notice: "Note removed." }
    end
  end

  private

  def note_params
    params.require(:note).permit(:body)
  end
end
