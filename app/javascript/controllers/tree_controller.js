import { Controller } from "@hotwired/stimulus"

// Renders a genealogical family tree: couples sit side by side joined by a
// marriage line, and a single line drops from each couple to a horizontal bar
// that branches down to their children. Supports pan/zoom and viewpoint
// relabelling. The kinship terms come from a server-computed matrix — the engine
// is never run on the client.
export default class extends Controller {
  static values = {
    nodes: Array,
    parentEdges: Array,
    spouseEdges: Array,
    terms: Object
  }

  static NODE_W = 112
  static NODE_H = 92
  static SIBLING_GAP = 34   // horizontal gap between adjacent sibling units
  static COUPLE_GAP = 46    // gap between two partners (the marriage line spans it)
  static V_GAP = 92         // vertical gap between generations
  static LINE = "#94a3b8"

  connect() {
    this.buildIndexes()
    this.positions = new Map()
    this.families = []
    this.nodeEls = new Map()

    this.buildStage()
    this.layout()
    this.draw()
    this.fitToView()
    this.setupPanZoom()
  }

  // Frame the whole family within the viewport on load.
  fitToView() {
    const contentW = Number(this.svg.getAttribute("width"))
    const contentH = Number(this.svg.getAttribute("height"))
    const boxW = this.element.clientWidth || contentW
    const boxH = this.element.clientHeight || contentH
    const padding = 32

    this.scale = Math.min((boxW - padding) / contentW, (boxH - padding) / contentH, 1)
    this.tx = Math.max(padding / 2, (boxW - contentW * this.scale) / 2)
    this.ty = padding / 2
  }

  // ---- indexes ------------------------------------------------------------

  buildIndexes() {
    const C = this.constructor
    this.nodeById = new Map(this.nodesValue.map((n) => [ n.id, n ]))
    this.orderIndex = new Map(this.nodesValue.map((n, i) => [ n.id, i ]))

    this.spouseOf = new Map()
    this.spouseEdgesValue.forEach(([ a, b ]) => {
      if (!this.spouseOf.has(a)) this.spouseOf.set(a, b)
      if (!this.spouseOf.has(b)) this.spouseOf.set(b, a)
    })

    // in-set parents per child, and children grouped by their parent-set key
    this.parentsOf = new Map()
    this.parentEdgesValue.forEach(([ parent, child ]) => {
      if (!this.nodeById.has(parent) || !this.nodeById.has(child)) return
      const list = this.parentsOf.get(child) || []
      list.push(parent)
      this.parentsOf.set(child, list)
    })

    this.childrenByKey = new Map()
    this.childrenOfPerson = new Map()
    this.parentsOf.forEach((parents, child) => {
      const key = [ ...parents ].sort().join("-")
      const list = this.childrenByKey.get(key) || []
      list.push(child)
      this.childrenByKey.set(key, list)

      parents.forEach((p) => {
        const kids = this.childrenOfPerson.get(p) || []
        kids.push(child)
        this.childrenOfPerson.set(p, kids)
      })
    })

    this.yOf = (level) => 24 + level * (C.NODE_H + C.V_GAP)
    this.placed = new Set()
    this.cursorX = 0
  }

  hasParents(id) {
    return (this.parentsOf.get(id) || []).length > 0
  }

  // Children belonging to a unit: kids of the couple, or of either partner alone.
  unitChildren(a, b) {
    const keys = b ? [ [ a, b ].sort().join("-"), String(a), String(b) ] : [ String(a) ]
    const ids = []
    keys.forEach((k) => (this.childrenByKey.get(k) || []).forEach((c) => ids.push(c)))
    return [ ...new Set(ids) ].sort((x, y) => this.orderIndex.get(x) - this.orderIndex.get(y))
  }

  // ---- layout -------------------------------------------------------------

  layout() {
    const roots = this.rootUnits()
    roots.forEach(([ a, b ]) => this.layoutUnit(a, b))
    this.placeLeftovers()
    this.resolveOverlaps()
    this.sizeSvg()
  }

  // Recursive centering can overlap couples when in-law branches interleave.
  // Per generation, keep couples together and push overlapping blocks apart.
  resolveOverlaps() {
    const C = this.constructor
    const BLOCK_GAP = 48
    const levels = new Map()
    this.positions.forEach((pos, id) => {
      const level = this.nodeById.get(id).level
      if (!levels.has(level)) levels.set(level, [])
      levels.get(level).push(id)
    })

    levels.forEach((ids) => {
      ids.sort((a, b) => this.positions.get(a).x - this.positions.get(b).x)
      const seen = new Set()
      const blocks = []
      ids.forEach((id) => {
        if (seen.has(id)) return
        const spouse = this.spouseOf.get(id)
        const coupled = spouse && this.positions.has(spouse) && !seen.has(spouse) &&
          this.nodeById.get(spouse).level === this.nodeById.get(id).level
        if (coupled) {
          const pair = [ id, spouse ].sort((a, b) => this.positions.get(a).x - this.positions.get(b).x)
          blocks.push(pair); seen.add(id); seen.add(spouse)
        } else {
          blocks.push([ id ]); seen.add(id)
        }
      })

      let cursor = -Infinity
      blocks.forEach((block) => {
        const width = block.length === 2 ? 2 * C.NODE_W + C.COUPLE_GAP : C.NODE_W
        const left = Math.max(this.positions.get(block[0]).x, cursor)
        this.positions.get(block[0]).x = left
        if (block.length === 2) this.positions.get(block[1]).x = left + C.NODE_W + C.COUPLE_GAP
        cursor = left + width + BLOCK_GAP
      })
    })
  }

  // Top-generation units: a person with no parents whose partner (if any) also
  // has no parents. Married-in spouses attach via their partner instead.
  rootUnits() {
    const units = []
    const used = new Set()
    this.nodesValue.forEach((n) => {
      if (used.has(n.id) || this.hasParents(n.id)) return
      const spouse = this.spouseOf.get(n.id)
      if (spouse && this.hasParents(spouse)) return // attaches via partner
      used.add(n.id)
      if (spouse && !used.has(spouse)) {
        used.add(spouse)
        units.push([ n.id, spouse ])
      } else {
        units.push([ n.id, null ])
      }
    })
    return units
  }

  // Places a unit (couple or single) and its descendants; returns its center x.
  layoutUnit(a, b) {
    if (this.placed.has(a)) return this.centerXOf(a, b)
    this.placed.add(a)
    if (b) this.placed.add(b)

    const children = this.unitChildren(a, b)
    if (children.length === 0) {
      return this.placeAtCursor(a, b)
    }

    const centers = children.map((child) => {
      const spouse = this.spouseOf.get(child)
      const partner = spouse && !this.placed.has(spouse) && this.hasParents(child) ? spouse : null
      return this.layoutUnit(child, partner)
    })
    const centerX = (Math.min(...centers) + Math.max(...centers)) / 2
    this.placeAtCenter(a, b, centerX)
    return centerX
  }

  unitWidth(b) {
    const C = this.constructor
    return b ? 2 * C.NODE_W + C.COUPLE_GAP : C.NODE_W
  }

  placeAtCursor(a, b) {
    const C = this.constructor
    const width = this.unitWidth(b)
    const centerX = this.cursorX + width / 2
    this.placeAt(a, b, centerX)
    this.cursorX += width + C.SIBLING_GAP
    return centerX
  }

  placeAtCenter(a, b, centerX) {
    this.placeAt(a, b, centerX)
    this.cursorX = Math.max(this.cursorX, centerX + this.unitWidth(b) / 2 + this.constructor.SIBLING_GAP)
  }

  placeAt(a, b, centerX) {
    const C = this.constructor
    const width = this.unitWidth(b)
    const leftX = centerX - width / 2
    this.positions.set(a, { x: leftX, y: this.yOf(this.nodeById.get(a).level) })
    if (b) this.positions.set(b, { x: leftX + C.NODE_W + C.COUPLE_GAP, y: this.yOf(this.nodeById.get(b).level) })
    this.families.push({ a, b, children: this.unitChildren(a, b), centerX })
  }

  centerXOf(a, b) {
    const pa = this.positions.get(a)
    return b ? pa.x + this.constructor.NODE_W + this.constructor.COUPLE_GAP / 2 : pa.x + this.constructor.NODE_W / 2
  }

  // Any node not reached above (isolated people) gets a slot on its own level.
  placeLeftovers() {
    this.nodesValue.forEach((n) => {
      if (this.positions.has(n.id)) return
      this.placeAtCursor(n.id, null)
    })
  }

  // ---- drawing ------------------------------------------------------------

  buildStage() {
    this.element.style.position = "relative"
    this.element.style.cursor = "grab"
    this.world = document.createElement("div")
    this.world.style.cssText = "position:absolute;top:0;left:0;transform-origin:0 0;"
    this.element.appendChild(this.world)
    this.svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    this.svg.style.cssText = "position:absolute;top:0;left:0;overflow:visible;pointer-events:none;"
    this.world.appendChild(this.svg)
    this.tx = 40
    this.ty = 20
    this.scale = 1
  }

  sizeSvg() {
    const C = this.constructor
    let maxX = 0
    let maxY = 0
    this.positions.forEach(({ x, y }) => {
      maxX = Math.max(maxX, x + C.NODE_W)
      maxY = Math.max(maxY, y + C.NODE_H)
    })
    this.svg.setAttribute("width", maxX + 40)
    this.svg.setAttribute("height", maxY + 40)
  }

  draw() {
    this.families.forEach((f) => this.drawFamily(f))
    this.nodesValue.forEach((n) => this.drawNode(n))
  }

  line(x1, y1, x2, y2) {
    const el = document.createElementNS("http://www.w3.org/2000/svg", "line")
    el.setAttribute("x1", x1); el.setAttribute("y1", y1)
    el.setAttribute("x2", x2); el.setAttribute("y2", y2)
    el.setAttribute("stroke", this.constructor.LINE)
    el.setAttribute("stroke-width", "1.5")
    this.svg.appendChild(el)
    return el
  }

  drawFamily(f) {
    const C = this.constructor
    const pa = this.positions.get(f.a)
    const marriageY = pa.y + C.NODE_H / 2
    f.lineEls = []          // lineage lines above the children bar (parent side)
    f.childDropEls = new Map()

    // Marriage line between the two partners (partner order may have changed).
    let dropX = pa.x + C.NODE_W / 2
    if (f.b) {
      const pb = this.positions.get(f.b)
      const leftX = Math.min(pa.x, pb.x)
      const rightX = Math.max(pa.x, pb.x)
      f.marriageEl = this.line(leftX + C.NODE_W, marriageY, rightX, marriageY)
      dropX = (leftX + C.NODE_W + rightX) / 2
    }
    if (f.children.length === 0) return

    // Drop from the couple (or single parent) down to the sibling bar.
    const dropStartY = f.b ? marriageY : pa.y + C.NODE_H
    const childTops = f.children.map((c) => this.positions.get(c).y)
    const busY = Math.min(...childTops) - C.V_GAP / 2
    f.lineEls.push(this.line(dropX, dropStartY, dropX, busY))

    // Horizontal sibling bar, extended to meet the drop.
    const childCenters = f.children.map((c) => this.positions.get(c).x + C.NODE_W / 2)
    const left = Math.min(dropX, ...childCenters)
    const right = Math.max(dropX, ...childCenters)
    f.lineEls.push(this.line(left, busY, right, busY))

    // Drop from the bar to each child.
    f.children.forEach((c) => {
      const cx = this.positions.get(c).x + C.NODE_W / 2
      f.childDropEls.set(c, this.line(cx, busY, cx, this.positions.get(c).y))
    })
  }

  drawNode(n) {
    const C = this.constructor
    const { x, y } = this.positions.get(n.id)
    const card = document.createElement("div")
    card.dataset.nodeId = n.id
    card.style.cssText =
      `position:absolute;left:${x}px;top:${y}px;width:${C.NODE_W}px;` +
      "display:flex;flex-direction:column;align-items:center;text-align:center;cursor:pointer;"

    const avatar = document.createElement("div")
    avatar.style.cssText =
      "width:48px;height:48px;border-radius:9999px;overflow:hidden;display:flex;" +
      "align-items:center;justify-content:center;background:#e0e7ff;color:#4338ca;font-weight:600;" +
      "border:2px solid #fff;box-shadow:0 1px 2px rgba(0,0,0,.1);"
    if (n.portrait_url) {
      const img = document.createElement("img")
      img.src = n.portrait_url
      img.alt = n.name
      img.style.cssText = "width:100%;height:100%;object-fit:cover;"
      avatar.appendChild(img)
    } else {
      avatar.textContent = (n.name || "?").charAt(0)
    }

    const name = document.createElement("div")
    name.className = "node-name"
    name.textContent = n.name
    name.style.cssText = "margin-top:4px;font-size:12px;font-weight:600;color:#111827;"

    const term = document.createElement("div")
    term.className = "node-term"
    term.dataset.nodeTerm = n.id
    term.style.cssText = "font-size:12px;color:#4f46e5;min-height:16px;"

    card.append(avatar, name, term)
    card.addEventListener("click", (e) => {
      e.stopPropagation()
      this.selectViewpoint(n.id)
    })
    this.world.appendChild(card)
    this.nodeEls.set(n.id, card)
  }

  // Relabel every node with the term the chosen viewpoint uses for them.
  selectViewpoint(id) {
    this.viewpointId = id
    const terms = this.termsValue[id] || {}
    this.nodeEls.forEach((card, nodeId) => {
      const termEl = card.querySelector(".node-term")
      const isViewpoint = nodeId === id
      card.style.outline = isViewpoint ? "2px solid #4f46e5" : "none"
      card.style.borderRadius = "8px"
      termEl.textContent = isViewpoint ? "— bạn —" : (terms[nodeId] || "")
    })
    this.highlightLineage(id)

    const hint = document.getElementById("viewpoint-hint")
    if (hint) {
      const self = this.nodeById.get(id)
      hint.textContent = `Viewing as ${self ? self.name : ""} — each label is how this person addresses them.`
    }
  }

  // Thicken the direct blood line of the viewpoint: up through parents/grandparents
  // and down through children/grandchildren.
  highlightLineage(id) {
    const lineage = this.lineageSet(id)
    const C = this.constructor

    this.families.forEach((f) => {
      const style = (el, on) => {
        if (!el) return
        el.setAttribute("stroke", on ? "#4f46e5" : C.LINE)
        el.setAttribute("stroke-width", on ? "3" : "1.5")
      }
      const parentInLineage = lineage.has(f.a) || (f.b && lineage.has(f.b))
      let anyChildInLineage = false

      f.childDropEls.forEach((el, child) => {
        const on = parentInLineage && lineage.has(child)
        if (on) anyChildInLineage = true
        style(el, on)
      })
      ;(f.lineEls || []).forEach((el) => style(el, anyChildInLineage))
      style(f.marriageEl, parentInLineage)
    })
  }

  lineageSet(id) {
    const set = new Set([ id ])
    const walk = (start, nextOf) => {
      const stack = [ start ]
      while (stack.length) {
        const current = stack.pop()
        ;(nextOf.get(current) || []).forEach((next) => {
          if (!set.has(next)) { set.add(next); stack.push(next) }
        })
      }
    }
    walk(id, this.parentsOf)        // ancestors
    walk(id, this.childrenOfPerson) // descendants
    return set
  }

  // ---- pan / zoom ---------------------------------------------------------

  setupPanZoom() {
    this.applyTransform()
    let dragging = false
    let startX = 0
    let startY = 0
    this.element.addEventListener("pointerdown", (e) => {
      dragging = true
      startX = e.clientX - this.tx
      startY = e.clientY - this.ty
      this.element.style.cursor = "grabbing"
    })
    window.addEventListener("pointermove", (e) => {
      if (!dragging) return
      this.tx = e.clientX - startX
      this.ty = e.clientY - startY
      this.applyTransform()
    })
    window.addEventListener("pointerup", () => {
      dragging = false
      this.element.style.cursor = "grab"
    })
    this.element.addEventListener("wheel", (e) => {
      e.preventDefault()
      const factor = e.deltaY < 0 ? 1.1 : 0.9
      this.scale = Math.min(2.5, Math.max(0.3, this.scale * factor))
      this.applyTransform()
    }, { passive: false })
  }

  applyTransform() {
    this.world.style.transform = `translate(${this.tx}px, ${this.ty}px) scale(${this.scale})`
  }
}
