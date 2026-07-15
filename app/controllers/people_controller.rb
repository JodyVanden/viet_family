class PeopleController < ApplicationController
  before_action :set_person, only: %i[show edit update destroy]

  def index
    @people = Person.order(:birth_date, :name).with_attached_portrait
  end

  def show
    @notes = @person.notes.order(created_at: :desc)
  end

  def new
    @person = Person.new
  end

  def edit; end

  def create
    @person = Person.new(person_params)
    if @person.save
      redirect_to @person, notice: "Person was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @person.update(person_params)
      redirect_to @person, notice: "Person was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @person.destroy
    redirect_to people_path, notice: "Person was removed."
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def person_params
    params.require(:person).permit(:name, :gender, :birth_date, :death_date, :birth_order, :portrait)
  end
end
