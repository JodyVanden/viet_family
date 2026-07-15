class RelationshipsController < ApplicationController
  # Adds an edge from the perspective of a person: choosing "Parent" links the
  # selected person as this person's parent, "Child" the reverse, "Spouse" a
  # symmetric edge.
  def create
    person = Person.find(params[:person_id])
    related = Person.find(params[:related_person_id])
    relationship = build_relationship(person, related, params[:relation])

    if relationship&.save
      redirect_to person, notice: "Relationship added."
    else
      message = relationship ? relationship.errors.full_messages.to_sentence : "Unknown relation."
      redirect_to person, alert: message.presence || "Could not add relationship."
    end
  end

  def destroy
    relationship = Relationship.find(params[:id])
    relationship.destroy
    redirect_to person_path(params[:person_id]), notice: "Relationship removed."
  end

  private

  def build_relationship(person, related, relation)
    case relation
    when "parent" then Relationship.new(from_person: related, to_person: person, kind: "parent")
    when "child"  then Relationship.new(from_person: person, to_person: related, kind: "parent")
    when "spouse" then Relationship.new(from_person: person, to_person: related, kind: "spouse")
    end
  end
end
