# ============================================================
# Model: Facility
#
# Desc:
# Repräsentiert eine wissenschaftliche Einrichtung aus der
# SciPort-Datenbank.
#
# Das Model verwaltet:
# - die Hierarchie zwischen Einrichtungen,
# - die Zugehörigkeit von Forschenden über Rollen,
# - die Verknüpfung mit Forschungsprojekten,
# - die Verknüpfung mit wissenschaftlichen Publikationen.
#
# Anwendungsfälle:
# - Einrichtungen im Forschungsnetzwerk darstellen
# - Forschende nach Einrichtungen filtern
# - Institutionelle Zugehörigkeiten untersuchen
# - Einrichtungen und ihre Untereinrichtungen analysieren
# ============================================================

class Facility < ApplicationRecord
  # ----------------------------------------------------------
  # 1. Hierarchische Beziehungen zwischen Einrichtungen
  #
  # Eine Einrichtung kann einer übergeordneten Einrichtung
  # zugeordnet sein und mehrere Untereinrichtungen besitzen.
  # Dadurch lassen sich beispielsweise Hochschulen und
  # ihre organisatorischen Untereinheiten abbilden.
  #
  # Wird eine Einrichtung gelöscht, bleiben ihre
  # Untereinrichtungen erhalten und verlieren nur ihre
  # übergeordnete Einrichtung.
  # ----------------------------------------------------------

  belongs_to :parent,
             class_name: "Facility",
             optional: true,
             inverse_of: :sub_facilities

  has_many :sub_facilities,
           class_name: "Facility",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :nullify


  # ----------------------------------------------------------
  # 2. Beziehungen zu Rollen und Forschenden
  #
  # Rollen verbinden Einrichtungen mit Forschenden.
  # Über diese Beziehungen kann das Forschungsnetzwerk
  # anzeigen, welche Personen einer Einrichtung angehören.
  #
  # distinct verhindert, dass eine Person doppelt erscheint,
  # wenn sie mehrere Rollen in derselben Einrichtung hat.
  # Beim Löschen einer Einrichtung werden ihre Rollen
  # mitgelöscht.
  # ----------------------------------------------------------

  has_many :roles, dependent: :destroy, inverse_of: :facility

  has_many :people, -> { distinct }, through: :roles


  # ----------------------------------------------------------
  # 3. Beziehungen zu Forschungsprojekten
  #
  # Eine Einrichtung kann an mehreren Forschungsprojekten
  # beteiligt sein. Ein Projekt kann wiederum mit mehreren
  # Einrichtungen verbunden sein.
  #
  # Diese Beziehung unterstützt später die Untersuchung
  # institutioneller Projektbeteiligungen.
  # ----------------------------------------------------------

  has_and_belongs_to_many :research_projects


  # ----------------------------------------------------------
  # 4. Beziehungen zu wissenschaftlichen Publikationen
  #
  # Einrichtungen können mit mehreren wissenschaftlichen
  # Publikationen verknüpft sein. Damit lassen sich später
  # Publikationen nach institutioneller Beteiligung auswerten.
  # ----------------------------------------------------------

  has_and_belongs_to_many :publications


  # ----------------------------------------------------------
  # 5. Validierung der externen ID und des Namens
  #
  # Die external_id ist die ID der Einrichtung auf
  # rlp-forschung.de. Sie muss eindeutig sein, damit der
  # Importer bestehende Einrichtungen wiederfindet.
  #
  # Der Name wird im Einrichtungsfilter, in Tooltips und
  # im Detailbereich angezeigt und muss deshalb vorhanden sein.
  # ----------------------------------------------------------

  validates :external_id, presence: true, uniqueness: true

  validates :name, presence: true


  # ----------------------------------------------------------
  # 6. Validierung der Hierarchie
  #
  # Eine Einrichtung darf weder sich selbst noch eine ihrer
  # Untereinrichtungen als übergeordnete Einrichtung haben.
  # Sonst entstünde ein Kreis in der Hierarchie.
  # ----------------------------------------------------------

  validate :parent_is_not_self_or_descendant


  # ----------------------------------------------------------
  # 7. Scopes für Filter und Auswahllisten
  #
  # top_level liefert die obersten Einrichtungen, z. B.
  # Hochschulen, als Ausgangspunkte für hierarchische Filter.
  # alphabetical sortiert Einrichtungen nach ihrem Namen.
  # ----------------------------------------------------------

  scope :top_level, -> { where(parent_id: nil) }

  scope :alphabetical, -> { order(:name) }


  # ----------------------------------------------------------
  # 8. Methoden für die Visualisierung
  # ----------------------------------------------------------

  # /*
  # Title: display_name
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Wissenschaftliche Einrichtungen identifizieren".
  #
  # Die Methode liefert den Namen einer Einrichtung für
  # die Anzeige im Einrichtungsfilter, in Tooltips und
  # im Detailbereich des Forschungsnetzwerks.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet das Attribut name des Facility-Objekts.
  #
  # Returns:
  # - String mit dem Namen der Einrichtung.
  # */
  def display_name
    name.to_s.strip
  end


  # /*
  # Title: root_facility?
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Hierarchische Einrichtungen unterscheiden".
  #
  # Die Methode prüft, ob eine Einrichtung keine
  # übergeordnete Einrichtung besitzt. Solche Einrichtungen
  # können später als Ausgangspunkte für hierarchische
  # Einrichtungsfilter verwendet werden.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet parent_id des Facility-Objekts.
  #
  # Returns:
  # - true, wenn keine übergeordnete Einrichtung existiert.
  # - false, wenn eine übergeordnete Einrichtung existiert.
  # */
  def root_facility?
    parent_id.nil?
  end

  # /*
  # Title: root_facility
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Zugehörige Hochschule einer Einrichtung ermitteln".
  #
  # Die Methode folgt der Hierarchie nach oben bis zur
  # obersten Einrichtung. Sie ersetzt das Element
  # <root-facility> aus dem Personen-XML.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet parent des Facility-Objekts.
  #
  # Returns:
  # - Facility-Objekt ohne übergeordnete Einrichtung.
  # - Die Einrichtung selbst, wenn sie bereits oberste ist.
  # */
  def root_facility
    node = self
    node = node.parent while node.parent
    node
  end


  # /*
  # Title: second_level_facility
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Forschungsnetzwerk auf Zoomstufe 2 anzeigen".
  #
  # Das Netzwerk fasst auf Stufe 2 alle tieferen Einheiten
  # zu ihrer Untereinrichtung direkt unter der obersten
  # Einrichtung zusammen. Die Methode folgt der Hierarchie
  # nach oben, bis die übergeordnete Einrichtung die oberste
  # ist. Visualization::NetworkGraph bildet damit die
  # Sammelkanten zwischen Untereinrichtungen.
  #
  # Beispiel:
  #   Hochschule Worms (Ebene 1)
  #   └── Fachbereich Informatik (Ebene 2)  ← Ergebnis
  #       └── Forschungsgruppe UX-Vis (Ebene 3)
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet parent des Facility-Objekts.
  #
  # Returns:
  # - Facility-Objekt der zweiten Hierarchieebene.
  # - Die Einrichtung selbst, wenn sie oberste Einrichtung
  #   oder bereits eine Einrichtung der zweiten Ebene ist.
  # */
  def second_level_facility
    return self if root_facility?

    node = self
    node = node.parent until node.parent.root_facility?
    node
  end

  private

  # /*
  # Title: parent_is_not_self_or_descendant
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Gültige Einrichtungshierarchie sicherstellen".
  #
  # Die Methode folgt der Hierarchie von der übergeordneten
  # Einrichtung nach oben. Trifft sie dabei auf die
  # Einrichtung selbst, liegt ein Kreis vor.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet parent des Facility-Objekts.
  #
  # Returns:
  # - Nichts. Bei einem Kreis wird ein Fehler zu :parent
  #   hinzugefügt und das Speichern verhindert.
  # */
  def parent_is_not_self_or_descendant
    node = parent
    while node
      if node == self
        errors.add(:parent, "darf nicht die Einrichtung selbst oder eine ihrer Untereinrichtungen sein")
        return
      end
      node = node.parent
    end
  end
end
